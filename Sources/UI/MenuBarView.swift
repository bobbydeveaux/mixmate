import SwiftUI
import AppKit
import ServiceManagement

struct MenuBarView: View {
    @ObservedObject var audioManager: AudioProcessManager
    @State private var launchAtLogin: Bool = SMAppService.mainApp.status == .enabled

    private var teamsSessions: [AppAudioSession] {
        audioManager.sessions.filter {
            AudioProcessManager.teamsBundleIDs.contains($0.bundleID)
        }
    }

    private var otherSessions: [AppAudioSession] {
        audioManager.sessions.filter {
            !AudioProcessManager.teamsBundleIDs.contains($0.bundleID)
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            // Header
            header

            Divider()

            if !audioManager.isProcessTapAvailable {
                // Error state: macOS version too old
                unsupportedView
            } else if let error = audioManager.permissionError {
                errorView(message: error)
            } else if audioManager.sessions.isEmpty {
                emptyStateView
            } else {
                // Session list
                ScrollView {
                    VStack(spacing: 8) {
                        // Teams section (pinned)
                        if !teamsSessions.isEmpty {
                            ForEach(teamsSessions) { session in
                                AppVolumeRow(session: session, isTeams: true)
                            }

                            if !otherSessions.isEmpty {
                                HStack {
                                    Rectangle()
                                        .fill(Color(NSColor.separatorColor))
                                        .frame(height: 1)
                                    Text("Other Apps")
                                        .font(.caption2)
                                        .foregroundColor(.secondary)
                                        .fixedSize()
                                    Rectangle()
                                        .fill(Color(NSColor.separatorColor))
                                        .frame(height: 1)
                                }
                                .padding(.horizontal, 14)
                            }
                        }

                        // Other apps
                        ForEach(otherSessions) { session in
                            AppVolumeRow(session: session, isTeams: false)
                        }
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 10)
                }
                .frame(maxHeight: 320)
            }

            Divider()

            // Footer
            footer
        }
        .frame(width: 320)
        .background(Color(NSColor.windowBackgroundColor))
    }

    // MARK: - Subviews

    private var header: some View {
        HStack {
            Image(systemName: "speaker.wave.2.fill")
                .foregroundColor(.accentColor)
                .font(.system(size: 15, weight: .semibold))
            Text("MixMate")
                .font(.headline)
            Spacer()
            Button {
                audioManager.refresh()
            } label: {
                Image(systemName: "arrow.clockwise")
                    .font(.system(size: 12))
                    .foregroundColor(.secondary)
            }
            .buttonStyle(.plain)
            .help("Refresh audio sources")
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
    }

    private var emptyStateView: some View {
        VStack(spacing: 10) {
            Image(systemName: "speaker.slash.fill")
                .font(.system(size: 36))
                .foregroundColor(.secondary)
            Text("No apps playing audio")
                .font(.subheadline)
                .foregroundColor(.secondary)
            Text("Apps will appear here when they play sound.")
                .font(.caption)
                .foregroundColor(Color(NSColor.tertiaryLabelColor))
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 36)
        .padding(.horizontal, 20)
    }

    private var unsupportedView: some View {
        VStack(spacing: 12) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 36))
                .foregroundColor(.orange)
            Text("macOS 14.2 Required")
                .font(.headline)
            Text("Per-app audio control requires macOS Sonoma 14.2 or later.\n\nPlease update macOS in System Settings → General → Software Update.")
                .font(.caption)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 28)
        .padding(.horizontal, 20)
    }

    private func errorView(message: String) -> some View {
        VStack(spacing: 12) {
            Image(systemName: "exclamationmark.shield.fill")
                .font(.system(size: 36))
                .foregroundColor(.red)
            Text("Error")
                .font(.headline)
            Text(message)
                .font(.caption)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 28)
        .padding(.horizontal, 20)
    }

    private var footer: some View {
        HStack {
            Toggle(isOn: $launchAtLogin) {
                Text("Launch at Login")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .toggleStyle(.checkbox)
            .onChange(of: launchAtLogin) { _, newValue in
                setLaunchAtLogin(newValue)
            }

            Spacer()

            Button("Quit") {
                NSApp.terminate(nil)
            }
            .font(.caption)
            .buttonStyle(.plain)
            .foregroundColor(.secondary)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
    }

    // MARK: - Launch at Login

    private func setLaunchAtLogin(_ enabled: Bool) {
        do {
            if enabled {
                try SMAppService.mainApp.register()
            } else {
                try SMAppService.mainApp.unregister()
            }
        } catch {
            print("MixMate: Launch at login toggle failed: \(error)")
        }
    }
}
