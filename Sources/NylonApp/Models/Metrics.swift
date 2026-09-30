// nylon's metric for a route that can't be used; INFM and up print as "INF", like `nylon status`
let INF = UInt32.max
let INFM = INF - 1

// Each peer's best metric from nylon's /metrics, the "best metric" column of `nylon status`:
// the lowest metric among the peer's active endpoints, else INF (`bestEndpoint` in nylon's cmd/status.go).
// nil when the text isn't nylon's, e.g. another server on the same port.
func readBestMetrics(_ text: String) -> [String: UInt32]? {
    var isNylon = false
    var best: [String: UInt32] = [:]
    // keyed by the endpoint's labels, which its active and metric lines share
    var endpoints: [Substring: (peer: String, active: Bool, metric: UInt32)] = [:]
    for line in text.split(separator: "\n") {
        if line == "nylon_up 1" { isNylon = true }
        // name{key="value",...} value
        guard let m = line.wholeMatch(of: #/(\w+)\{(.*)\} (\S+)/#) else { continue }
        var labels: [String: String] = [:]
        for l in m.2.matches(of: #/(\w+)="((?:[^"\\]|\\.)*)"/#) { labels[String(l.1)] = String(l.2) }
        guard let peer = labels["peer"] else { continue }
        best[peer] = INF // every peer is listed, even a passive client with no endpoints
        switch m.1 {
        case "nylon_endpoint_active": endpoints[m.2, default: (peer, false, INF)].active = m.3 == "1"
        case "nylon_endpoint_metric": endpoints[m.2, default: (peer, false, INF)].metric = UInt32(m.3) ?? INF
        default: break
        }
    }
    for e in endpoints.values where e.active {
        best[e.peer] = min(best[e.peer] ?? INF, e.metric)
    }
    return isNylon ? best : nil
}
