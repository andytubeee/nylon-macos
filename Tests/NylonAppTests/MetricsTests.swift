import Foundation
import Testing
@testable import NylonApp

// A trimmed-down nylon /metrics response
@Test func readsPeers() {
    let text = """
    # HELP nylon_up Whether the nylon daemon is ready.
    # TYPE nylon_up gauge
    nylon_up 1
    nylon_wireguard_peer_latest_handshake_seconds{peer="phone"} 0
    nylon_wireguard_peer_latest_handshake_seconds{peer="laptop"} 1790376600
    nylon_wireguard_peer_latest_handshake_seconds{peer="bob"} 1790376629
    nylon_endpoint_active{endpoint="10.10.0.3:57175",peer="bob"} 0
    nylon_endpoint_active{endpoint="bob.example.com",peer="bob"} 1
    nylon_endpoint_active{endpoint="[fd00::3]:57175",peer="bob"} 1
    nylon_endpoint_active{endpoint="10.10.0.5:57175",peer="carol"} 0
    nylon_endpoint_active{endpoint="10.10.0.7:57175",peer="dave"} 1
    nylon_endpoint_metric{endpoint="10.10.0.3:57175",peer="bob"} 900
    nylon_endpoint_metric{endpoint="bob.example.com",peer="bob"} 12034
    nylon_endpoint_metric{endpoint="[fd00::3]:57175",peer="bob"} 31000
    nylon_endpoint_metric{endpoint="10.10.0.5:57175",peer="carol"} 4294967295
    nylon_endpoint_metric{endpoint="10.10.0.7:57175",peer="dave"} 4294967295
    nylon_route_metric{next_hop="bob",prefix="10.0.0.2/32",router="bob"} 12034
    """
    // bob: the lowest active endpoint (the inactive 900 doesn't count); carol: none active;
    // dave: active but no ping measured yet, so still INF;
    // phone and laptop: passive clients, no endpoints
    #expect(readPeers(text) == [
        "bob": Peer(metric: 12034, handshake: 1790376629),
        "carol": Peer(),
        "dave": Peer(),
        "phone": Peer(),
        "laptop": Peer(handshake: 1790376600),
    ])
}

@Test func describesPeers() {
    let now = Date(timeIntervalSince1970: 1790376700)
    #expect(statusText(Peer(metric: 1746), now: now) == "1.7ms")
    #expect(statusText(Peer(metric: 37473), now: now) == "37.5ms")
    #expect(statusText(Peer(handshake: 1790376600), now: now) == "connected") // 100s ago
    #expect(statusText(Peer(handshake: 1790376520), now: now) == "offline") // exactly 180s ago: WireGuard has dropped it
    #expect(statusText(Peer(metric: INFM, handshake: 1790376690), now: now) == "connected") // no latency yet, live tunnel
    #expect(statusText(Peer(), now: now) == "offline") // never
}

// e.g. Prometheus itself, which also serves /metrics on 9090
@Test func rejectsOtherServers() {
    #expect(readPeers("prometheus_build_info{version=\"3.0.0\"} 1") == nil)
}
