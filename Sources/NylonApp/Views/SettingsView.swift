import AppKit
import SwiftUI

// The Settings window: where the app finds central.yaml and nylon's metrics.
struct SettingsView: View {
    @ObservedObject var store: NodeStore

    var body: some View {
        Form {
            LabeledContent("central.yaml") {
                Text(store.nodes == nil ? "Can't read \(store.path)" : store.path)
                Button("Choose…") { chooseCentral() }
            }
            TextField("Metrics URL", text: $store.metricsURL)
            Text(store.peers == nil ? "nylon isn't answering there. Set observability_addr in node.yaml." : "nylon is answering.")
                .foregroundStyle(.secondary)
        }
        .formStyle(.grouped)
        .frame(width: 480)
    }

    private func chooseCentral() {
        let panel = NSOpenPanel()
        if panel.runModal() == .OK, let url = panel.url {
            store.choose(url.path)
        }
    }
}

// The menu bar icon. On a launch with no readable central.yaml it opens Settings, so a new user isn't left guessing.
struct MenuBarIcon: View {
    let image: NSImage
    let needsSetup: Bool
    @Environment(\.openSettings) private var openSettings

    var body: some View {
        Image(nsImage: image)
            .accessibilityLabel("Nylon")
            .task {
                guard needsSetup else { return }
                NSApp.activate() // a menu bar app runs in the background, so bring the window to the front
                openSettings()
            }
    }
}
