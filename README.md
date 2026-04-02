# MixMate

A macOS menu bar app for per-app volume control. Targets Microsoft Teams but shows all apps playing audio.

## Requirements

- macOS 14.2 (Sonoma) or later — required for `AudioHardwareCreateProcessTap`
- Xcode 15.2+ or Swift 5.9+

## Features

- Lives in the menu bar (no Dock icon)
- Shows a popover with sliders for each app currently playing audio
- Microsoft Teams pinned at the top when present
- Per-app mute button
- Launch at Login toggle
- Shows app icon and name for each audio source
- Graceful fallback message on macOS < 14.2

## Building

### With Swift Package Manager

```bash
swift build -c release
```

The resulting binary is at `.build/release/MixMate`.

### With Xcode

Open the project folder in Xcode:

```bash
xed .
```

Or generate an Xcode project:

```bash
swift package generate-xcodeproj
```

## Architecture

```
Sources/
├── App/
│   ├── MixMateApp.swift          — @main entry point, SwiftUI App
│   └── AppDelegate.swift         — NSStatusItem, NSPopover, EventMonitor
├── Audio/
│   ├── AudioProcessManager.swift — CoreAudio process enumeration + tap lifecycle
│   └── AppAudioSession.swift     — Per-app tap + AVAudioEngine volume control
└── UI/
    ├── MenuBarView.swift          — Popover root view
    └── AppVolumeRow.swift         — Per-app row with slider and mute button
```

## How It Works

1. `AudioProcessManager` calls `kAudioHardwarePropertyProcessObjectList` to enumerate all CoreAudio process objects.
2. For each process it reads `kAudioProcessPropertyPID`, `kAudioProcessPropertyBundleID`, and `kAudioProcessPropertyIsRunningOutput` to discover active audio producers.
3. For each discovered process, an `AppAudioSession` is created which calls `AudioHardwareCreateProcessTap` (macOS 14.2+) to intercept the audio stream.
4. An `AVAudioEngine` with an `AVAudioMixerNode` applies per-app volume gain before routing to the default output device.
5. The UI polls every 2 seconds for new/departed processes and updates the popover accordingly.

## Permissions

On first run macOS may prompt for microphone access — this is required for the process tap API to capture other apps' audio. Grant access in **System Settings → Privacy & Security → Microphone**.

## License

MIT — see [LICENSE](LICENSE).
