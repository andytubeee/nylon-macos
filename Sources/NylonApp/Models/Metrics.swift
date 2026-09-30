import Foundation

// nylon's metric for a route that can't be used; INFM and up print as "INF", like `nylon status`
let INF = UInt32.max
let INFM = INF - 1

// Each peer's best metric from nylon's /metrics, the "best metric" column of `nylon status`:
// the lowest metric among the peer's active endpoints, else INF (`bestEndpoint` in nylon's cmd/status.go).
func readBestMetrics(_ text: String) -> [String: UInt32] {
    var best: [String: UInt32] = [:]
    var metric: [[String]: UInt32] = [:] // [peer, endpoint] -> that endpoint's metric
    var active: Set<[String]> = []
    for line in text.split(separator: "\n") {
        // name{key="value",...} value; # lines and series without a peer don't match
        guard let m = line.wholeMatch(of: #/(\w+)\{(.*)\} (\S+)/#) else { continue }
        var labels: [String: String] = [:]
        for l in m.2.matches(of: #/(\w+)="((?:[^"\\]|\\.)*)"/#) { labels[String(l.1)] = String(l.2) }
        guard let peer = labels["peer"] else { continue }
        best[peer] = INF // every peer is listed, even a passive client with no endpoints
        let endpoint = [peer, labels["endpoint"] ?? ""]
        switch m.1 {
        case "nylon_endpoint_metric": metric[endpoint] = UInt32(exactly: Double(m.3) ?? -1)
        case "nylon_endpoint_active" where m.3 == "1": active.insert(endpoint)
        default: break
        }
    }
    for endpoint in active {
        best[endpoint[0]] = min(best[endpoint[0]]!, metric[endpoint] ?? INF)
    }
    return best
}
