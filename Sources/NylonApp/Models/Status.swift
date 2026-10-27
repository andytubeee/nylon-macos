import Foundation

// A metric nylon can't use: the link is down or not measured yet. INFM and up mean the same.
let INF = UInt32.max
let INFM = INF - 1

// A peer from `nylon status`
struct Peer: Equatable {
    // lowest among its active endpoints, else INF
    var metric = INF
    var handshake: Double = 0 // Unix time of the latest WireGuard handshake; 0 means never
}

// Every peer in a `nylon status` reply, by node id. nil unless the reply is a successful status.
func readPeers(_ reply: Data) -> [String: Peer]? {
    guard let reply = try? JSONDecoder().decode(Reply.self, from: reply), reply.ok, let status = reply.status else { return nil }
    var peers: [String: Peer] = [:]
    for n in status.neighbours ?? [] {
        let active = (n.endpoints ?? []).filter(\.active).map(\.metric)
        // protojson writes int64 as a string, here in nanoseconds
        let handshake = (Double(n.wireguard?.latestHandshakeUnix ?? "") ?? 0) / 1e9
        peers[n.peerId] = Peer(metric: active.min() ?? INF, handshake: handshake)
    }
    return peers
}

// The parts of nylon's IpcResponse read here (protojson field names)
private struct Reply: Decodable {
    struct Status: Decodable { let neighbours: [Neighbour]? }
    struct Neighbour: Decodable {
        struct Endpoint: Decodable { let active: Bool; let metric: UInt32 }
        struct WireGuard: Decodable { let latestHandshakeUnix: String? }
        let peerId: String
        let endpoints: [Endpoint]?
        let wireguard: WireGuard?
    }
    let ok: Bool
    let status: Status?
}
