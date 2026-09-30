import AppKit
import SwiftUI

struct MenuContent: View {
    @ObservedObject var store: NodeStore

    var body: some View {
        Text(store.peers == nil ? "Not running, or observability_addr isn't set" : "Running")
        if let nodes = store.nodes {
            ForEach(nodes, id: \.name) { NodeRow(node: $0, peer: store.peers?[$0.name]) }
        } else {
            Text("Can't read \(store.path)")
        }
        Divider()
        Button("Choose central.yaml…") { chooseCentral() }
        Button("Quit") { NSApplication.shared.terminate(nil) }
    }

    private func chooseCentral() {
        NSApp.activate() // a menu bar app runs in the background, so bring the picker to the front
        let panel = NSOpenPanel()
        if panel.runModal() == .OK, let url = panel.url {
            store.choose(url.path)
        }
    }
}

// A node's name, IP and, for a peer, its latency or whether it's connected. Clicking it copies the IP.
struct NodeRow: View {
    let node: Node
    let peer: Peer? // nil when the node isn't a peer of this one, e.g. this device itself

    var body: some View {
        Button(label) {
            NSPasteboard.general.clearContents()
            NSPasteboard.general.setString(node.address ?? "", forType: .string)
        }
        .disabled(node.address == nil)
    }

    private var label: String {
        var label = "\(node.name)  \(node.address ?? "no address")"
        if let peer { label += "  \(statusText(peer))" }
        return label
    }
}
