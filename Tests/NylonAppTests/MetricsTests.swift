import Testing
@testable import NylonApp

// In the format nylon's writePrometheusMetrics prints
@Test func readsBestMetrics() {
    let text = """
    # HELP nylon_up Whether the nylon daemon is ready.
    # TYPE nylon_up gauge
    nylon_up 1
    nylon_wireguard_peer_latest_handshake_seconds{peer="phone"} 0
    nylon_wireguard_peer_latest_handshake_seconds{peer="bob"} 1790376629
    nylon_endpoint_active{endpoint="10.10.0.3:57175",peer="bob"} 0
    nylon_endpoint_active{endpoint="bob.example.com",peer="bob"} 1
    nylon_endpoint_active{endpoint="[fd00::3]:57175",peer="bob"} 1
    nylon_endpoint_active{endpoint="10.10.0.5:57175",peer="carol"} 0
    nylon_endpoint_metric{endpoint="10.10.0.3:57175",peer="bob"} 900
    nylon_endpoint_metric{endpoint="bob.example.com",peer="bob"} 12034
    nylon_endpoint_metric{endpoint="[fd00::3]:57175",peer="bob"} 31000
    nylon_endpoint_metric{endpoint="10.10.0.5:57175",peer="carol"} 4294967295
    nylon_route_metric{next_hop="bob",prefix="10.0.0.2/32",router="bob"} 12034
    """
    // bob: the lowest active endpoint (the inactive 900 doesn't count); carol: none active; phone: a passive client, no endpoints
    #expect(readBestMetrics(text) == ["bob": 12034, "carol": INF, "phone": INF])
}

@Test func readsNothingFromGarbage() {
    #expect(readBestMetrics("<html>not metrics</html>").isEmpty)
}
