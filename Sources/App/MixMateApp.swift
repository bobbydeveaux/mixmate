import SwiftUI
import AppKit

@main
struct MixMateApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        // No window scenes — this is a menu bar only app.
        // The AppDelegate manages the NSStatusItem and popover.
        Settings {
            EmptyView()
        }
    }
}
