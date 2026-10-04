import AppKit
import SwiftUI

// The Settings window: where the app finds central.yaml and nylon's metrics.
struct SettingsView: View {
    @ObservedObject var store: NodeStore
    private static let logo = Bundle.module.image(forResource: "Logo")! // built into the app, so it can't be missing

    var body: some View {
        VStack(spacing: 0) {
            header
            VStack(alignment: .leading, spacing: 22) {
                Setting(
                    title: "Network file",
                    isWorking: store.nodes != nil,
                    status: store.nodes.map { "\($0.count) nodes in this network." } ?? "Can't read this file. Choose your central.yaml."
                ) {
                    HStack {
                        Text(store.path)
                            .font(.system(.body, design: .monospaced))
                            .lineLimit(1)
                            .truncationMode(.middle) // a long path keeps its start and its file name
                        Spacer()
                        Button("Choose…") { chooseCentral() }
                    }
                }
                Setting(
                    title: "Metrics address",
                    isWorking: store.peers != nil,
                    status: store.peers == nil
                        ? "No answer. Add observability_addr: 127.0.0.1:9090 to node.yaml, then restart nylon."
                        : "nylon is answering."
                ) {
                    TextField("http://127.0.0.1:9090/metrics", text: $store.metricsURL)
                        .textFieldStyle(.roundedBorder)
                        .font(.system(.body, design: .monospaced))
                }
            }
            .padding(24)
        }
        .frame(width: 480)
        .fixedSize(horizontal: false, vertical: true) // as tall as its content, no taller
    }

    // The logo on its own black, so its disc melts into the band and only the strands show
    private var header: some View {
        HStack(spacing: 14) {
            Image(nsImage: Self.logo)
                .resizable()
                .frame(width: 48, height: 48)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 2) {
                Text("nylon").font(.system(size: 24, weight: .semibold, design: .rounded))
                Text("A self-healing WireGuard mesh").font(.callout).opacity(0.6)
            }
            Spacer()
        }
        .foregroundStyle(.white)
        .padding(.horizontal, 20)
        .padding(.vertical, 16)
        .background(.black)
    }

    private func chooseCentral() {
        let panel = NSOpenPanel()
        if panel.runModal() == .OK, let url = panel.url { store.choose(url.path) }
    }
}

// One setting, marked by a strand like the logo's: blue while it works, red while it doesn't.
private struct Setting<Control: View>: View {
    let title: String
    let isWorking: Bool
    let status: String // says the same as the strand's colour, in words
    @ViewBuilder let control: Control

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Capsule()
                .fill(isWorking ? Color(red: 34 / 255, green: 173 / 255, blue: 1) : Color(red: 1, green: 56 / 255, blue: 56 / 255))
                .frame(width: 5)
            VStack(alignment: .leading, spacing: 7) {
                Text(title).font(.headline)
                control
                Text(status).font(.callout).foregroundStyle(.secondary)
            }
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
            .task { if needsSetup { showSettings(openSettings) } }
    }
}

// A menu bar app has no Dock icon and isn't in Cmd-Tab, so its window gets lost behind others.
// While a window is open the app is a regular one; MenuApp turns it back when the last window closes.
@MainActor func showSettings(_ openSettings: OpenSettingsAction) {
    NSApp.setActivationPolicy(.regular)
    NSApp.activate()
    openSettings()
}
