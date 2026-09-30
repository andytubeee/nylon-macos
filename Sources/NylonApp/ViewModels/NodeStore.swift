import Foundation

// What the menu shows. Views read it; where the data comes from stays in here.
// ObservableObject, since @State is a macro the Command Line Tools can't expand (no SwiftUI macro plugin).
@MainActor
final class NodeStore: ObservableObject {
    @Published private(set) var path = ""
    @Published private(set) var nodes: [Node]? // nil when central.yaml can't be read
    @Published private(set) var metrics: [String: UInt32]? // each peer's best metric; nil while nylon's /metrics doesn't answer

    // A path picked earlier or passed as `-central <path>` (both land in UserDefaults), else ./central.yaml like `nylon run`
    init() {
        load(UserDefaults.standard.string(forKey: "central") ?? "central.yaml")
        Task { await poll() }
    }

    // Picked from the menu, so remember it for the next launch.
    func choose(_ path: String) {
        UserDefaults.standard.set(path, forKey: "central")
        load(path)
    }

    private func load(_ path: String) {
        // absolute and with ~ expanded, so "Can't read" says where it looked
        self.path = URL(fileURLWithPath: NSString(string: path).expandingTildeInPath).path
        nodes = try? readNodes(String(contentsOfFile: self.path, encoding: .utf8))
    }

    // nylon serves /metrics at node.yaml's observability_addr; `-metrics <url>` points elsewhere
    private func poll() async {
        guard let url = URL(string: UserDefaults.standard.string(forKey: "metrics") ?? "http://127.0.0.1:9090/metrics") else { return }
        while true {
            metrics = try? await fetch(url)
            try? await Task.sleep(for: .seconds(5))
        }
    }

    private func fetch(_ url: URL) async throws -> [String: UInt32]? {
        let request = URLRequest(url: url, cachePolicy: .reloadIgnoringLocalCacheData, timeoutInterval: 2) // always live numbers
        let (data, response) = try await URLSession.shared.data(for: request)
        guard (response as? HTTPURLResponse)?.statusCode == 200 else { return nil }
        return readBestMetrics(String(decoding: data, as: UTF8.self))
    }
}
