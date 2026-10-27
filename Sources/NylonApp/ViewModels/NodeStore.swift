import AppKit
import ServiceManagement

// What the menu shows. Views read it; where the data comes from stays in here.
// ObservableObject, since @State is a macro the Command Line Tools can't expand (no SwiftUI macro plugin).
@MainActor
final class NodeStore: ObservableObject {
    @Published private(set) var path = ""
    @Published private(set) var nodes: [Node]? // nil when central.yaml can't be read
    @Published private(set) var peers: [String: Peer]? // by node id; nil while nylon doesn't answer
    @Published private(set) var needsAdmin = false // nylon's socket is root only and the helper isn't approved or reachable
    // where nylon keeps its IPC socket; `-socket-dir <path>` points at a fake one for development
    private let nylonDir = UserDefaults.standard.string(forKey: "socket-dir") ?? "/var/run/wireguard"

    // The file picked in Settings or passed as `-central <path>` (both land in UserDefaults), else ./central.yaml like `nylon run`
    init() {
        load(UserDefaults.standard.string(forKey: "central") ?? "central.yaml")
        Task { await poll() }
    }

    // Picked in Settings, so remember it for the next launch.
    func choose(_ path: String) {
        UserDefaults.standard.set(path, forKey: "central")
        load(path)
    }

    private func load(_ path: String) {
        // absolute and with ~ expanded, so "Can't read" says where it looked
        self.path = URL(fileURLWithPath: NSString(string: path).expandingTildeInPath).path
        nodes = try? readNodes(String(contentsOfFile: self.path, encoding: .utf8))
    }

    // Registers the root helper (see Helper.swift). macOS asks the user once to approve it in Login Items.
    func allowAccess() {
        try? helperDaemon.register()
        if helperDaemon.status == .requiresApproval { SMAppService.openSystemSettingsLoginItems() }
    }

    private func poll() async {
        while true {
            await refresh()
            try? await Task.sleep(for: .seconds(5))
        }
    }

    private func refresh() async {
        let result = await fetch()
        // Updating rows under an open menu makes its highlight jump, so wait until it closes.
        guard RunLoop.main.currentMode != .eventTracking else { return }
        peers = try? result.get()
        if case .failure = result { needsAdmin = true } else { needsAdmin = false } // refused, and no working helper
    }

    // nylon's socket directly (works in dev, or with an ACL for this user), else through the helper once it's approved
    private func fetch() async -> Result<[String: Peer]?, Error> {
        let dir = nylonDir
        let helperEnabled = helperDaemon.status == .enabled
        return await Task.detached { // socket and XPC calls block
            let direct = Result { try fetchPeers(in: dir) }
            guard case .failure = direct, helperEnabled else { return direct }
            // a fresh connection each time: one made before the helper was approved stays invalid
            let connection = NSXPCConnection(machServiceName: helperService, options: .privileged)
            connection.remoteObjectInterface = NSXPCInterface(with: NylonHelper.self)
            connection.resume()
            defer { connection.invalidate() }
            return Result { try helperStatus(connection).flatMap(readPeers) }
        }.value
    }
}

// A peer's latency once nylon has measured one, else whether its WireGuard tunnel is up.
// nylon never measures passive clients, so for them the tunnel is the only sign they're online.
func statusText(_ peer: Peer, now: Date = Date()) -> String {
    if peer.metric < INFM { return String(format: "%.1fms", Double(peer.metric) / 1000) } // metric is in µs
    return now.timeIntervalSince1970 - peer.handshake < 180 ? "connected" : "offline" // WireGuard drops a session after 180s
}
