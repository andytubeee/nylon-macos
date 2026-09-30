// nylon's metric for a link it can't use (down, or no ping measured yet); INFM and up mean the same
let INF = UInt32.max
let INFM = INF - 1

// A peer as nylon's /metrics describes it
struct Peer: Equatable {
    // the "best metric" column of `nylon status`: the lowest metric among active endpoints, else INF
    // (`bestEndpoint` in nylon's cmd/status.go)
    var metric = INF
    var handshake: Double = 0 // Unix time of the latest WireGuard handshake; 0 means never
}

// Every peer in nylon's /metrics, by node id.
// nil when the text isn't nylon's, e.g. another server on the same port.
func readPeers(_ text: String) -> [String: Peer]? {
    var isNylon = false
    var peers: [String: Peer] = [:]
    // keyed by the endpoint's labels, which its active and metric lines share
    var endpoints: [Substring: (peer: String, active: Bool, metric: UInt32)] = [:]
    for line in text.split(separator: "\n") {
        if line == "nylon_up 1" { isNylon = true }
        // name{key="value",...} value
        guard let m = line.wholeMatch(of: #/(\w+)\{(.*)\} (\S+)/#) else { continue }
        var labels: [String: String] = [:]
        for l in m.2.matches(of: #/(\w+)="((?:[^"\\]|\\.)*)"/#) { labels[String(l.1)] = String(l.2) }
        guard let peer = labels["peer"] else { continue }
        if peers[peer] == nil { peers[peer] = Peer() } // every peer is listed, even a passive client with no endpoints
        switch m.1 {
        case "nylon_wireguard_peer_latest_handshake_seconds": peers[peer]?.handshake = Double(m.3) ?? 0
        case "nylon_endpoint_active": endpoints[m.2, default: (peer, false, INF)].active = m.3 == "1"
        case "nylon_endpoint_metric": endpoints[m.2, default: (peer, false, INF)].metric = UInt32(m.3) ?? INF
        default: break
        }
    }
    for e in endpoints.values where e.active && e.metric < peers[e.peer]?.metric ?? INF {
        peers[e.peer]?.metric = e.metric
    }
    return isNylon ? peers : nil
}
