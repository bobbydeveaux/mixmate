import Foundation
import CoreAudio
import AppKit

/// Represents a single application that is (or was recently) playing audio.
@MainActor
final class AppAudioSession: ObservableObject, Identifiable {
    let id: pid_t
    let bundleID: String
    let appName: String
    let appIcon: NSImage

    @Published var volume: Float = 1.0 {
        didSet { updateIOVolume() }
    }
    @Published var isMuted: Bool = false {
        didSet { updateIOVolume() }
    }
    @Published var isActive: Bool = true

    private var tapObjectID: AudioObjectID = kAudioObjectUnknown
    private var aggregateDeviceID: AudioDeviceID = kAudioObjectUnknown
    private var tapProcID: AudioDeviceIOProcID?
    private var ioProcRetainedSelf: Unmanaged<AppAudioSession>?

    // Written on MainActor, read on real-time IOProc thread — intentionally unsafe access
    // for performance; worst case is a brief volume glitch on a rare concurrent write.
    nonisolated(unsafe) private var _ioVolume: Float = 1.0

    nonisolated init(pid: pid_t, bundleID: String) {
        self.id = pid
        self.bundleID = bundleID

        let runningApp = NSRunningApplication(processIdentifier: pid)

        if let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleID) {
            // Known app with a registered bundle ID
            let bundle = Bundle(url: url)
            appName = bundle?.infoDictionary?["CFBundleDisplayName"] as? String
                   ?? bundle?.infoDictionary?["CFBundleName"] as? String
                   ?? runningApp?.localizedName
                   ?? bundleID.components(separatedBy: ".").last?.capitalized
                   ?? bundleID
            appIcon = NSWorkspace.shared.icon(forFile: url.path)
        } else if let execURL = runningApp?.executableURL {
            // Helper / renderer process — walk up to the nearest .app bundle for name + icon
            var appURL: URL? = nil
            var current = execURL
            while current.pathComponents.count > 1 {
                current = current.deletingLastPathComponent()
                if current.pathExtension == "app" { appURL = current; break }
            }
            if let appURL {
                let bundle = Bundle(url: appURL)
                appName = bundle?.infoDictionary?["CFBundleDisplayName"] as? String
                       ?? bundle?.infoDictionary?["CFBundleName"] as? String
                       ?? runningApp?.localizedName
                       ?? appURL.deletingPathExtension().lastPathComponent
                appIcon = NSWorkspace.shared.icon(forFile: appURL.path)
            } else {
                appName = runningApp?.localizedName
                       ?? execURL.deletingPathExtension().lastPathComponent.capitalized
                appIcon = runningApp?.icon ?? NSImage(systemSymbolName: "app.fill", accessibilityDescription: nil) ?? NSImage()
            }
        } else {
            appName = runningApp?.localizedName
                   ?? bundleID.components(separatedBy: ".").last?.capitalized
                   ?? bundleID
            appIcon = runningApp?.icon ?? NSImage(systemSymbolName: "app.fill", accessibilityDescription: nil) ?? NSImage()
        }
    }

    // MARK: - Tap lifecycle

    @discardableResult
    func startTap() -> Bool {
        guard #available(macOS 14.2, *) else { return false }

        let processObjectID = findProcessObjectID(for: id)
        guard processObjectID != kAudioObjectUnknown else {
            print("MixMate:","Could not find process object ID for PID \(id) (\(bundleID))")
            return false
        }

        // 1. Create tap description — mutedWhenTapped silences the app's direct output
        //    so only our processed audio (via the aggregate device) reaches the speakers.
        let tapDesc = CATapDescription(stereoMixdownOfProcesses: [processObjectID])
        tapDesc.name = "MixMate-\(bundleID)-\(id)"
        tapDesc.muteBehavior = .mutedWhenTapped

        var tapID: AudioObjectID = kAudioObjectUnknown
        let tapStatus = AudioHardwareCreateProcessTap(tapDesc, &tapID)
        guard tapStatus == noErr, tapID != kAudioObjectUnknown else {
            print("MixMate:","AudioHardwareCreateProcessTap failed for \(bundleID): \(tapStatus)")
            return false
        }
        tapObjectID = tapID

        // 2. Get default output device UID for the aggregate device
        guard let outputUID = defaultOutputDeviceUID() else {
            print("MixMate:","Could not get default output device UID")
            AudioHardwareDestroyProcessTap(tapID)
            tapObjectID = kAudioObjectUnknown
            return false
        }

        // 3. Create aggregate device: tap as input, default output as output.
        //    The IOProc on this device receives tap audio as input and writes to output.
        let tapUID = tapDesc.uuid.uuidString
        let aggDesc: [String: Any] = [
            kAudioAggregateDeviceNameKey: "MixMate-\(bundleID)",
            kAudioAggregateDeviceUIDKey: "com.mixmate.agg.\(id)",
            kAudioAggregateDeviceIsPrivateKey: 1 as UInt32,
            kAudioAggregateDeviceTapListKey: [
                [kAudioSubTapUIDKey: tapUID,
                 kAudioSubTapDriftCompensationKey: 0 as UInt32]
            ],
            kAudioAggregateDeviceSubDeviceListKey: [
                [kAudioSubDeviceUIDKey: outputUID]
            ],
            kAudioAggregateDeviceMasterSubDeviceKey: outputUID
        ]

        var aggID: AudioDeviceID = kAudioObjectUnknown
        let aggStatus = AudioHardwareCreateAggregateDevice(aggDesc as CFDictionary, &aggID)
        guard aggStatus == noErr, aggID != kAudioObjectUnknown else {
            print("MixMate:","AudioHardwareCreateAggregateDevice failed for \(bundleID): \(aggStatus)")
            AudioHardwareDestroyProcessTap(tapID)
            tapObjectID = kAudioObjectUnknown
            return false
        }
        aggregateDeviceID = aggID

        // 4. Install IOProc: copy tap input → output, scaling samples by volume
        installIOProc(on: aggID)
        return true
    }

    func stopTap() {
        if let procID = tapProcID {
            AudioDeviceStop(aggregateDeviceID, procID)
            AudioDeviceDestroyIOProcID(aggregateDeviceID, procID)
            tapProcID = nil
        }
        ioProcRetainedSelf?.release()
        ioProcRetainedSelf = nil

        if aggregateDeviceID != kAudioObjectUnknown {
            AudioHardwareDestroyAggregateDevice(aggregateDeviceID)
            aggregateDeviceID = kAudioObjectUnknown
        }
        if #available(macOS 14.2, *), tapObjectID != kAudioObjectUnknown {
            AudioHardwareDestroyProcessTap(tapObjectID)
            tapObjectID = kAudioObjectUnknown
        }
    }

    // MARK: - IOProc

    private func installIOProc(on deviceID: AudioDeviceID) {
        let retained = Unmanaged.passRetained(self)
        ioProcRetainedSelf = retained
        let selfPtr = retained.toOpaque()

        let ioProc: AudioDeviceIOProc = { _, _, inInputData, _, outOutputData, _, clientData in
            guard let ctx = clientData else { return noErr }

            let session = Unmanaged<AppAudioSession>.fromOpaque(ctx).takeUnretainedValue()
            let vol = session._ioVolume

            // Use raw pointer arithmetic to walk the AudioBufferList in-place.
            // withUnsafePointer(to: abl.mBuffers) copies only the first element,
            // so accessing beyond index 0 would read garbage for non-interleaved audio.
            let ablOffset = MemoryLayout<AudioBufferList>.offset(of: \.mBuffers)!
            let srcBuf = UnsafeRawPointer(inInputData).advanced(by: ablOffset)
                .assumingMemoryBound(to: AudioBuffer.self)
            let dstBuf = UnsafeMutableRawPointer(mutating: outOutputData).advanced(by: ablOffset)
                .assumingMemoryBound(to: AudioBuffer.self)

            let numIn  = Int(inInputData.pointee.mNumberBuffers)
            let numOut = Int(outOutputData.pointee.mNumberBuffers)

            for i in 0..<numOut {
                guard let dstData = dstBuf[i].mData else { continue }
                let dstCount = Int(dstBuf[i].mDataByteSize) / MemoryLayout<Float32>.size
                let dstPtr = dstData.assumingMemoryBound(to: Float32.self)

                if i < numIn, let srcData = srcBuf[i].mData {
                    let srcCount = Int(srcBuf[i].mDataByteSize) / MemoryLayout<Float32>.size
                    let srcPtr = srcData.assumingMemoryBound(to: Float32.self)
                    let n = min(srcCount, dstCount)
                    for j in 0..<n { dstPtr[j] = srcPtr[j] * vol }
                    // Zero any extra output samples this buffer didn't cover
                    if n < dstCount { dstPtr.advanced(by: n).update(repeating: 0, count: dstCount - n) }
                } else {
                    // No corresponding input buffer — silence
                    dstPtr.update(repeating: 0, count: dstCount)
                }
            }
            return noErr
        }

        var procID: AudioDeviceIOProcID?
        let status = AudioDeviceCreateIOProcID(deviceID, ioProc, selfPtr, &procID)
        if status == noErr, let procID = procID {
            tapProcID = procID
            AudioDeviceStart(deviceID, procID)
        } else {
            print("MixMate:","AudioDeviceCreateIOProcID failed for \(bundleID): \(status)")
            retained.release()
            ioProcRetainedSelf = nil
        }
    }

    // MARK: - Volume

    private func updateIOVolume() {
        _ioVolume = isMuted ? 0 : max(0, min(1, volume))
    }

    // MARK: - Helpers

    private func defaultOutputDeviceUID() -> String? {
        var deviceID: AudioDeviceID = kAudioObjectUnknown
        var addr = AudioObjectPropertyAddress(
            mSelector: kAudioHardwarePropertyDefaultOutputDevice,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        var size = UInt32(MemoryLayout<AudioDeviceID>.size)
        guard AudioObjectGetPropertyData(
            AudioObjectID(kAudioObjectSystemObject), &addr, 0, nil, &size, &deviceID
        ) == noErr else { return nil }

        var uidAddr = AudioObjectPropertyAddress(
            mSelector: kAudioDevicePropertyDeviceUID,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        var uid: Unmanaged<CFString>? = nil
        var uidSize = UInt32(MemoryLayout<Unmanaged<CFString>?>.size)
        guard AudioObjectGetPropertyData(deviceID, &uidAddr, 0, nil, &uidSize, &uid) == noErr,
              let unmanaged = uid else { return nil }
        return unmanaged.takeRetainedValue() as String
    }

    private func findProcessObjectID(for pid: pid_t) -> AudioObjectID {
        var address = AudioObjectPropertyAddress(
            mSelector: kAudioHardwarePropertyProcessObjectList,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        var dataSize: UInt32 = 0
        guard AudioObjectGetPropertyDataSize(
            AudioObjectID(kAudioObjectSystemObject), &address, 0, nil, &dataSize
        ) == noErr, dataSize > 0 else { return kAudioObjectUnknown }

        let count = Int(dataSize) / MemoryLayout<AudioObjectID>.size
        var objectIDs = [AudioObjectID](repeating: kAudioObjectUnknown, count: count)
        guard AudioObjectGetPropertyData(
            AudioObjectID(kAudioObjectSystemObject), &address, 0, nil, &dataSize, &objectIDs
        ) == noErr else { return kAudioObjectUnknown }

        for objectID in objectIDs where objectID != kAudioObjectUnknown {
            var pidAddress = AudioObjectPropertyAddress(
                mSelector: kAudioProcessPropertyPID,
                mScope: kAudioObjectPropertyScopeGlobal,
                mElement: kAudioObjectPropertyElementMain
            )
            var foundPID: pid_t = -1
            var size = UInt32(MemoryLayout<pid_t>.size)
            if AudioObjectGetPropertyData(objectID, &pidAddress, 0, nil, &size, &foundPID) == noErr,
               foundPID == pid {
                return objectID
            }
        }
        return kAudioObjectUnknown
    }

}
