import Foundation
import CoreAudio
import AVFoundation
import AppKit

// File log for debugging
func flog(_ msg: String) {
    let line = "\(Date()) \(msg)\n"
    if let data = line.data(using: .utf8) {
        let url = URL(fileURLWithPath: "/tmp/mixmate.log")
        if let fh = try? FileHandle(forWritingTo: url) {
            fh.seekToEndOfFile(); fh.write(data); try? fh.close()
        } else { try? data.write(to: url) }
    }
}

/// Represents a single application that is (or was recently) playing audio.
@MainActor
final class AppAudioSession: ObservableObject, Identifiable {
    let id: pid_t
    let bundleID: String
    let appName: String
    let appIcon: NSImage

    @Published var volume: Float = 1.0 { didSet { atomicVolume = effectiveVolume() } }
    @Published var isMuted: Bool = false { didSet { atomicVolume = effectiveVolume() } }
    @Published var isActive: Bool = true

    // Accessed from real-time IOProc thread — must be nonisolated
    nonisolated(unsafe) var atomicVolume: Float = 1.0
    nonisolated(unsafe) var ioProcCallCount: Int = 0

    private var tapObjectID: AudioObjectID = kAudioObjectUnknown
    private var aggregateDeviceID: AudioDeviceID = kAudioObjectUnknown
    private var ioProcID: AudioDeviceIOProcID?
    private var ioProcRetain: Unmanaged<AppAudioSession>?

    nonisolated init(pid: pid_t, bundleID: String) {
        self.id = pid
        self.bundleID = bundleID
        if let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleID) {
            let bundle = Bundle(url: url)
            appName = bundle?.infoDictionary?["CFBundleDisplayName"] as? String
                   ?? bundle?.infoDictionary?["CFBundleName"] as? String
                   ?? bundleID.components(separatedBy: ".").last?.capitalized ?? bundleID
            appIcon = NSWorkspace.shared.icon(forFile: url.path)
        } else {
            let app = NSRunningApplication(processIdentifier: pid)
            appName = app?.localizedName ?? bundleID.components(separatedBy: ".").last?.capitalized ?? bundleID
            appIcon = app?.icon ?? NSImage(systemSymbolName: "app.fill", accessibilityDescription: nil) ?? NSImage()
        }
    }

    // MARK: - Tap lifecycle

    @discardableResult
    func startTap() -> Bool {
        guard #available(macOS 14.2, *) else { return false }

        guard let outputUID = getDefaultOutputDeviceUID() else {
            flog("ERROR: no default output device UID")
            return false
        }

        let processObjectID = findProcessObjectID(for: id)
        guard processObjectID != kAudioObjectUnknown else {
            flog("ERROR: no process object for \(bundleID)")
            return false
        }

        // Tap — muted so original audio is silenced; we re-route it
        let tapDesc = CATapDescription(stereoMixdownOfProcesses: [processObjectID])
        tapDesc.name = "MixMate-\(bundleID)"
        tapDesc.muteBehavior = .muted

        var tapID: AudioObjectID = kAudioObjectUnknown
        guard AudioHardwareCreateProcessTap(tapDesc, &tapID) == noErr, tapID != kAudioObjectUnknown else {
            flog("ERROR: CreateProcessTap failed for \(bundleID)")
            return false
        }
        tapObjectID = tapID
        flog("Tap created for \(bundleID) id=\(tapID)")

        guard let tapUID = getTapUID(tapObjectID: tapID) else {
            flog("ERROR: no tap UID for \(bundleID)")
            AudioHardwareDestroyProcessTap(tapID); tapObjectID = kAudioObjectUnknown
            return false
        }

        // Aggregate device: tap (input) + real output device (output)
        // The output sub-device drives the I/O clock so IOProc fires.
        // IOProc reads from tap input, scales by volume, writes to output.
        let aggDesc: NSDictionary = [
            kAudioAggregateDeviceNameKey:       "MixMate-\(appName)",
            kAudioAggregateDeviceUIDKey:        "com.mixmate.agg.\(id)",
            kAudioAggregateDeviceTapListKey:    [[kAudioSubTapUIDKey: tapUID]],
            kAudioAggregateDeviceSubDeviceListKey: [[kAudioSubDeviceUIDKey: outputUID]],
            kAudioAggregateDeviceMainSubDeviceKey: outputUID,
            kAudioAggregateDeviceIsPrivateKey:  1
        ]
        var aggID: AudioDeviceID = kAudioObjectUnknown
        guard AudioHardwareCreateAggregateDevice(aggDesc, &aggID) == noErr, aggID != kAudioObjectUnknown else {
            flog("ERROR: CreateAggregateDevice failed for \(bundleID)")
            AudioHardwareDestroyProcessTap(tapID); tapObjectID = kAudioObjectUnknown
            return false
        }
        aggregateDeviceID = aggID
        flog("Aggregate device created for \(bundleID) deviceID=\(aggID)")

        // IOProc: tap input → volume scale → output
        let retained = Unmanaged.passRetained(self)
        ioProcRetain = retained
        let ctx = retained.toOpaque()

        let ioProc: AudioDeviceIOProc = { _, _, inInputData, _, outOutputData, _, clientData in
            guard let ctx = clientData else { return noErr }
            let inABL = inInputData
            let outABL = outOutputData

            let session = Unmanaged<AppAudioSession>.fromOpaque(ctx).takeUnretainedValue()
            let vol = session.atomicVolume

            // Log first few calls to confirm IOProc is firing
            session.ioProcCallCount += 1
            if session.ioProcCallCount == 1 || session.ioProcCallCount == 100 {
                let inBufs = Int(inABL.pointee.mNumberBuffers)
                let outBufs = Int(outABL.pointee.mNumberBuffers)
                let inBytes = inBufs > 0 ? Int(inABL.pointee.mBuffers.mDataByteSize) : 0
                DispatchQueue.global(qos: .background).async {
                    flog("IOProc #\(session.ioProcCallCount) for \(session.bundleID): inBufs=\(inBufs) outBufs=\(outBufs) inBytes=\(inBytes) vol=\(vol)")
                }
            }

            let inBuffers  = UnsafeBufferPointer<AudioBuffer>(
                start: &UnsafeMutablePointer(mutating: inABL).pointee.mBuffers,
                count: Int(inABL.pointee.mNumberBuffers))
            let outBuffers = UnsafeMutableBufferPointer<AudioBuffer>(
                start: &outABL.pointee.mBuffers,
                count: Int(outABL.pointee.mNumberBuffers))

            for (src, dst) in zip(inBuffers, outBuffers) {
                let frames = Int(min(src.mDataByteSize, dst.mDataByteSize)) / MemoryLayout<Float32>.size
                if let s = src.mData?.assumingMemoryBound(to: Float32.self),
                   let d = dst.mData?.assumingMemoryBound(to: Float32.self) {
                    for i in 0..<frames { d[i] = s[i] * vol }
                }
            }
            return noErr
        }

        var procID: AudioDeviceIOProcID?
        guard AudioDeviceCreateIOProcID(aggID, ioProc, ctx, &procID) == noErr, let procID else {
            flog("ERROR: CreateIOProcID failed for \(bundleID)")
            retained.release(); ioProcRetain = nil
            AudioHardwareDestroyAggregateDevice(aggID); aggregateDeviceID = kAudioObjectUnknown
            AudioHardwareDestroyProcessTap(tapID); tapObjectID = kAudioObjectUnknown
            return false
        }
        ioProcID = procID
        AudioDeviceStart(aggID, procID)
        flog("IOProc started — volume scaling active for \(bundleID)")
        return true
    }

    func stopTap() {
        if let procID = ioProcID {
            AudioDeviceStop(aggregateDeviceID, procID)
            AudioDeviceDestroyIOProcID(aggregateDeviceID, procID)
            ioProcID = nil
        }
        ioProcRetain?.release(); ioProcRetain = nil
        if aggregateDeviceID != kAudioObjectUnknown {
            AudioHardwareDestroyAggregateDevice(aggregateDeviceID)
            aggregateDeviceID = kAudioObjectUnknown
        }
        if tapObjectID != kAudioObjectUnknown {
            if #available(macOS 14.2, *) { AudioHardwareDestroyProcessTap(tapObjectID) }
            tapObjectID = kAudioObjectUnknown
        }
    }

    // MARK: - Volume

    private func effectiveVolume() -> Float { isMuted ? 0 : max(0, min(1, volume)) }
    private func applyVolume() { atomicVolume = effectiveVolume() }

    // MARK: - CoreAudio helpers

    private func getDefaultOutputDeviceUID() -> String? {
        var addr = AudioObjectPropertyAddress(mSelector: kAudioHardwarePropertyDefaultOutputDevice, mScope: kAudioObjectPropertyScopeGlobal, mElement: kAudioObjectPropertyElementMain)
        var deviceID: AudioDeviceID = kAudioObjectUnknown
        var size = UInt32(MemoryLayout<AudioDeviceID>.size)
        guard AudioObjectGetPropertyData(AudioObjectID(kAudioObjectSystemObject), &addr, 0, nil, &size, &deviceID) == noErr else { return nil }
        var uidAddr = AudioObjectPropertyAddress(mSelector: kAudioDevicePropertyDeviceUID, mScope: kAudioObjectPropertyScopeGlobal, mElement: kAudioObjectPropertyElementMain)
        var rawUID: Unmanaged<CFString>? = nil
        var uidSize = UInt32(MemoryLayout<Unmanaged<CFString>?>.size)
        guard withUnsafeMutablePointer(to: &rawUID, { AudioObjectGetPropertyData(deviceID, &uidAddr, 0, nil, &uidSize, UnsafeMutableRawPointer($0)) }) == noErr,
              let u = rawUID else { return nil }
        return u.takeRetainedValue() as String
    }

    private func getTapUID(tapObjectID: AudioObjectID) -> String? {
        var addr = AudioObjectPropertyAddress(mSelector: kAudioTapPropertyUID, mScope: kAudioObjectPropertyScopeGlobal, mElement: kAudioObjectPropertyElementMain)
        var raw: Unmanaged<CFString>? = nil
        var size = UInt32(MemoryLayout<Unmanaged<CFString>?>.size)
        guard withUnsafeMutablePointer(to: &raw, { AudioObjectGetPropertyData(tapObjectID, &addr, 0, nil, &size, UnsafeMutableRawPointer($0)) }) == noErr,
              let u = raw else { return nil }
        return u.takeRetainedValue() as String
    }

    private func findProcessObjectID(for pid: pid_t) -> AudioObjectID {
        var addr = AudioObjectPropertyAddress(mSelector: kAudioHardwarePropertyProcessObjectList, mScope: kAudioObjectPropertyScopeGlobal, mElement: kAudioObjectPropertyElementMain)
        var dataSize: UInt32 = 0
        guard AudioObjectGetPropertyDataSize(AudioObjectID(kAudioObjectSystemObject), &addr, 0, nil, &dataSize) == noErr, dataSize > 0 else { return kAudioObjectUnknown }
        let count = Int(dataSize) / MemoryLayout<AudioObjectID>.size
        var ids = [AudioObjectID](repeating: kAudioObjectUnknown, count: count)
        guard AudioObjectGetPropertyData(AudioObjectID(kAudioObjectSystemObject), &addr, 0, nil, &dataSize, &ids) == noErr else { return kAudioObjectUnknown }
        for objectID in ids where objectID != kAudioObjectUnknown {
            var pidAddr = AudioObjectPropertyAddress(mSelector: kAudioProcessPropertyPID, mScope: kAudioObjectPropertyScopeGlobal, mElement: kAudioObjectPropertyElementMain)
            var foundPID: pid_t = -1; var sz = UInt32(MemoryLayout<pid_t>.size)
            if AudioObjectGetPropertyData(objectID, &pidAddr, 0, nil, &sz, &foundPID) == noErr, foundPID == pid { return objectID }
        }
        return kAudioObjectUnknown
    }
}
