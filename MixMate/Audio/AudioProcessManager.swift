import Foundation
import CoreAudio
import AppKit
import Combine

/// Manages discovery and lifecycle of all audio-playing processes.
@MainActor
final class AudioProcessManager: ObservableObject {
    @Published var sessions: [AppAudioSession] = []
    @Published var isProcessTapAvailable: Bool = false
    @Published var permissionError: String? = nil

    // Teams bundle IDs (Microsoft Teams Classic and new Teams)
    static let teamsBundleIDs: Set<String> = [
        "com.microsoft.teams",
        "com.microsoft.teams2"
    ]

    private var refreshTimer: Timer?
    private var knownPIDs: Set<pid_t> = []

    // MARK: - Lifecycle

    func startMonitoring() {
        flog("startMonitoring called")
        if #available(macOS 14.2, *) {
            isProcessTapAvailable = true
        } else {
            isProcessTapAvailable = false
            permissionError = "MixMate requires macOS 14.2 or later to control per-app volume."
            return
        }

        refresh()

        // Poll for new/departed audio processes every 2 seconds
        refreshTimer = Timer.scheduledTimer(withTimeInterval: 2.0, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.refresh()
            }
        }
    }

    func stopMonitoring() {
        refreshTimer?.invalidate()
        refreshTimer = nil
        for session in sessions {
            session.stopTap()
        }
        sessions.removeAll()
        knownPIDs.removeAll()
    }

    // MARK: - Refresh

    func refresh() {
        guard isProcessTapAvailable else { return }
        let discovered = enumerateAudioProcesses()

        let discoveredPIDs = Set(discovered.map { $0.pid })
        let existingPIDs = knownPIDs

        // Remove sessions for gone processes
        let removedPIDs = existingPIDs.subtracting(discoveredPIDs)
        if !removedPIDs.isEmpty {
            for pid in removedPIDs {
                if let idx = sessions.firstIndex(where: { $0.id == pid }) {
                    sessions[idx].stopTap()
                    sessions.remove(at: idx)
                }
            }
            knownPIDs.subtract(removedPIDs)
        }

        // Add sessions for new processes
        let addedPIDs = discoveredPIDs.subtracting(existingPIDs)
        for info in discovered where addedPIDs.contains(info.pid) {
            let session = AppAudioSession(pid: info.pid, bundleID: info.bundleID)
            _ = session.startTap()
            sessions.append(session)
            knownPIDs.insert(info.pid)
        }

        sortSessions()
    }

    // MARK: - Sorting

    private func sortSessions() {
        sessions.sort { a, b in
            let aIsTeams = Self.teamsBundleIDs.contains(a.bundleID)
            let bIsTeams = Self.teamsBundleIDs.contains(b.bundleID)
            if aIsTeams != bIsTeams { return aIsTeams }
            return a.appName.localizedCaseInsensitiveCompare(b.appName) == .orderedAscending
        }
    }

    // MARK: - CoreAudio Process Enumeration

    struct AudioProcessInfo {
        let pid: pid_t
        let bundleID: String
    }

    private func enumerateAudioProcesses() -> [AudioProcessInfo] {
        // 1. Get list of AudioObject IDs that are audio processes
        var address = AudioObjectPropertyAddress(
            mSelector: kAudioHardwarePropertyProcessObjectList,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )

        var dataSize: UInt32 = 0
        var status = AudioObjectGetPropertyDataSize(
            AudioObjectID(kAudioObjectSystemObject),
            &address,
            0, nil,
            &dataSize
        )
        guard status == noErr, dataSize > 0 else { return [] }

        let count = Int(dataSize) / MemoryLayout<AudioObjectID>.size
        var objectIDs = [AudioObjectID](repeating: kAudioObjectUnknown, count: count)
        status = AudioObjectGetPropertyData(
            AudioObjectID(kAudioObjectSystemObject),
            &address,
            0, nil,
            &dataSize,
            &objectIDs
        )
        guard status == noErr else { return [] }

        var results: [AudioProcessInfo] = []
        flog("enumerateAudioProcesses: found \(objectIDs.count) audio objects")

        for objectID in objectIDs {
            guard objectID != kAudioObjectUnknown else { continue }
            guard let pid = getPID(for: objectID) else { continue }
            if pid == ProcessInfo.processInfo.processIdentifier { continue }
            let bundleID = getBundleID(for: objectID) ?? inferBundleID(for: pid)
            guard !bundleID.isEmpty else { continue }
            // Skip known system daemons — show user-visible apps only
            guard !isSystemDaemon(bundleID: bundleID) else { continue }
            results.append(AudioProcessInfo(pid: pid, bundleID: bundleID))
        }

        return results
    }

    // MARK: - Property Helpers

    private func getPID(for objectID: AudioObjectID) -> pid_t? {
        var address = AudioObjectPropertyAddress(
            mSelector: kAudioProcessPropertyPID,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        var pid: pid_t = -1
        var size = UInt32(MemoryLayout<pid_t>.size)
        let status = AudioObjectGetPropertyData(objectID, &address, 0, nil, &size, &pid)
        return status == noErr ? pid : nil
    }

    private func getBundleID(for objectID: AudioObjectID) -> String? {
        var address = AudioObjectPropertyAddress(
            mSelector: kAudioProcessPropertyBundleID,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        var size: UInt32 = UInt32(MemoryLayout<CFString>.size)
        // CoreAudio returns a CFString by value in the buffer for string properties.
        // We allocate a raw buffer large enough for a CFTypeRef (pointer-sized).
        var rawValue: Unmanaged<CFString>? = nil
        let status = withUnsafeMutablePointer(to: &rawValue) { ptr -> OSStatus in
            AudioObjectGetPropertyData(
                objectID, &address, 0, nil, &size,
                UnsafeMutableRawPointer(ptr)
            )
        }
        guard status == noErr, let unmanaged = rawValue else { return nil }
        let result = unmanaged.takeRetainedValue() as String
        return result.isEmpty ? nil : result
    }

    private func isSystemDaemon(bundleID: String) -> Bool {
        let systemPrefixes = [
            "com.apple.audiomxd", "com.apple.audio.", "com.apple.mediaremoted",
            "com.apple.controlcenter", "com.apple.universalaccessd", "com.apple.cmio.",
            "com.apple.avconferenced", "com.apple.WebKit.GPU", "com.apple.CoreSpeech",
            "com.apple.loginwindow", "com.apple.TelephonyUtilities", "com.apple.SiriNCService",
            "com.apple.cloudpaird", "com.apple.assistantd", "com.apple.accessibility.heard",
            "com.apple.PowerChime", "com.apple.ScreenContinuity", "com.apple.MobileSMS",
            "com.apple.Siri", "systemsoundserverd"
        ]
        // Also skip .helper processes unless they're the main app
        if bundleID.hasSuffix(".helper") || bundleID.hasSuffix(".Helper") { return true }
        if bundleID.hasSuffix(".ServiceExtension") { return true }
        return systemPrefixes.contains(where: { bundleID.hasPrefix($0) })
    }

    private func inferBundleID(for pid: pid_t) -> String {
        NSRunningApplication(processIdentifier: pid)?.bundleIdentifier ?? ""
    }
}
