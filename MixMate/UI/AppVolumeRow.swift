import SwiftUI
import AppKit

struct AppVolumeRow: View {
    @ObservedObject var session: AppAudioSession
    let isTeams: Bool

    var body: some View {
        VStack(spacing: 6) {
            HStack(spacing: 10) {
                // App icon
                Image(nsImage: session.appIcon)
                    .resizable()
                    .interpolation(.high)
                    .frame(width: 28, height: 28)
                    .cornerRadius(6)
                    .shadow(color: .black.opacity(0.15), radius: 2, x: 0, y: 1)

                // App name
                VStack(alignment: .leading, spacing: 1) {
                    Text(session.appName)
                        .font(isTeams ? .headline : .subheadline)
                        .fontWeight(isTeams ? .semibold : .regular)
                        .foregroundColor(isTeams ? .primary : .primary)
                        .lineLimit(1)
                    if isTeams {
                        Text("Pinned")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                }

                Spacer()

                // Volume percentage
                Text("\(Int(session.volume * 100))%")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .frame(width: 34, alignment: .trailing)
                    .monospacedDigit()

                // Mute button
                Button {
                    session.isMuted.toggle()
                } label: {
                    Image(systemName: session.isMuted ? "speaker.slash.fill" : "speaker.wave.2.fill")
                        .font(.system(size: 14))
                        .foregroundColor(session.isMuted ? .red : .secondary)
                        .frame(width: 24, height: 24)
                }
                .buttonStyle(.plain)
                .help(session.isMuted ? "Unmute \(session.appName)" : "Mute \(session.appName)")
            }

            // Volume slider
            HStack(spacing: 8) {
                Image(systemName: "speaker.fill")
                    .font(.system(size: 10))
                    .foregroundColor(.secondary)

                Slider(value: $session.volume, in: 0...1) {
                    Text("Volume")
                } minimumValueLabel: {
                    EmptyView()
                } maximumValueLabel: {
                    EmptyView()
                }
                .disabled(session.isMuted)
                .tint(isTeams ? Color.accentColor : Color.secondary)
                .opacity(session.isMuted ? 0.4 : 1.0)

                Image(systemName: "speaker.wave.3.fill")
                    .font(.system(size: 10))
                    .foregroundColor(.secondary)
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(isTeams
                    ? Color.accentColor.opacity(0.07)
                    : Color(NSColor.controlBackgroundColor).opacity(0.6))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .strokeBorder(isTeams
                    ? Color.accentColor.opacity(0.3)
                    : Color(NSColor.separatorColor).opacity(0.5),
                    lineWidth: isTeams ? 1.5 : 0.5)
        )
    }
}
