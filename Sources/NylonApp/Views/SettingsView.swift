import AppKit
import SwiftUI

// The Settings window: where the app finds central.yaml.
struct SettingsView: View {
    @ObservedObject var store: NodeStore

    var body: some View {
        Form {
            Section {
                LabeledContent("central.yaml") {
                    Text(store.nodes == nil ? "Can't read \(store.path)" : store.path)
                        .lineLimit(1)
                        .truncationMode(.middle) // a long path keeps its start and its file name
                    Button("Choose…") { chooseCentral() }
                }
            }
        }
        .formStyle(.grouped)
        .frame(width: 480)
        .fixedSize(horizontal: false, vertical: true) // as tall as its rows, no taller
    }

    private func chooseCentral() {
        let panel = NSOpenPanel()
        if panel.runModal() == .OK, let url = panel.url { store.choose(url.path) }
    }
}

// The menu bar icon. On a launch with no readable central.yaml it opens Settings, so a new user isn't left guessing,
// and when nylon's socket turns out to need root it asks for admin access.
struct MenuBarIcon: View {
    let image: NSImage
    let needsSetup: Bool
    let needsAdmin: Bool
    let askForAdmin: () -> Void
    @Environment(\.openSettings) private var openSettings

    var body: some View {
        Image(nsImage: image)
            .accessibilityLabel("Nylon")
            .task { if needsSetup { showSettings(openSettings) } }
            .task(id: needsAdmin) {
                guard needsAdmin, !askedForAdmin else { return } // ask once a run; after that the menu offers it
                askedForAdmin = true
                askForAdmin()
            }
    }
}

@MainActor private var askedForAdmin = false

// A menu bar app has no Dock icon and isn't in Cmd-Tab, so its window gets lost behind others.
// While a window is open the app is a regular one; MenuApp turns it back when the last window closes.
@MainActor func showSettings(_ openSettings: OpenSettingsAction) {
    NSApp.setActivationPolicy(.regular)
    NSApp.activate()
    openSettings()
}
