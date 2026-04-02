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

        for objectID in objectIDs {
            guard objectID != kAudioObjectUnknown else { continue }

            // Get PID
            guard let pid = getPID(for: objectID) else { continue }

            // Skip ourselves
            if pid == ProcessInfo.processInfo.processIdentifier { continue }

            // Check if the process is running and has audio
            guard isProcessRunning(objectID) else { continue }

            // Get bundle ID — helper processes (e.g. Chrome renderer) may have none,
            // so fall back to a pid-based identifier so they still get tapped.
            let bundleID = getBundleID(for: objectID) ?? inferBundleID(for: pid)

            // Only include processes that are actually playing audio
            if isPlayingAudio(objectID: objectID, pid: pid) {
                results.append(AudioProcessInfo(pid: pid, bundleID: bundleID))
            }
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

    private func isProcessRunning(_ objectID: AudioObjectID) -> Bool {
        var address = AudioObjectPropertyAddress(
            mSelector: kAudioProcessPropertyIsRunning,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        var running: UInt32 = 0
        var size = UInt32(MemoryLayout<UInt32>.size)
        let status = AudioObjectGetPropertyData(objectID, &address, 0, nil, &size, &running)
        return status == noErr && running != 0
    }

    private func isPlayingAudio(objectID: AudioObjectID, pid: pid_t) -> Bool {
        // Check kAudioProcessPropertyIsRunningInput — non-zero means process has active audio I/O
        var address = AudioObjectPropertyAddress(
            mSelector: kAudioProcessPropertyIsRunningInput,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        var running: UInt32 = 0
        var size = UInt32(MemoryLayout<UInt32>.size)
        // Try output first (output = playback)
        address.mSelector = kAudioProcessPropertyIsRunningOutput
        let status = AudioObjectGetPropertyData(objectID, &address, 0, nil, &size, &running)

        if status == noErr && running != 0 {
            return true
        }

        // Fallback: check if the process has an NSRunningApplication and
        // owns a CoreAudio stream (some apps don't set IsRunning properly)
        if let app = NSRunningApplication(processIdentifier: pid) {
            return !app.isTerminated
        }
        return false
    }

    private func inferBundleID(for pid: pid_t) -> String {
        if let id = NSRunningApplication(processIdentifier: pid)?.bundleIdentifier, !id.isEmpty {
            return id
        }
        // For helper processes (e.g. Chrome renderer) that aren't registered as
        // NSRunningApplication entries, fall back to a stable pid-based key.
        return "pid.\(pid)"
    }
}
