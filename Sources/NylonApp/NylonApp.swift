import AppKit
import SwiftUI

@main
struct MenuApp: App {
    @StateObject private var store = NodeStore()
    private static let runningIcon = menuBarIcon("MenuBarRunning")
    private static let stoppedIcon = menuBarIcon("MenuBarStopped")

    init() {
        // menu bar only; without an app bundle it would otherwise start background-only
        NSApplication.shared.setActivationPolicy(.accessory)
    }

    var body: some Scene {
        MenuBarExtra {
            MenuContent(store: store)
        } label: {
            MenuBarIcon(image: store.peers == nil ? Self.stoppedIcon : Self.runningIcon, needsSetup: store.nodes == nil)
        }
        Settings {
            SettingsView(store: store)
        }
    }
}

// An SVG from Resources/, sized for the menu bar
func menuBarIcon(_ name: String) -> NSImage {
    let image = Bundle.module.image(forResource: name)! // built into the app, so it can't be missing
    image.size = NSSize(width: 18, height: 18)
    image.isTemplate = true // macOS tints it to match a light or dark menu bar
    return image
}
