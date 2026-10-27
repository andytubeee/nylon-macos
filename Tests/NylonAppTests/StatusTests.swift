import Foundation
import Testing
@testable import NylonApp

// A trimmed `nylon status` reply as protojson writes it: int64 as strings, handshakes in nanoseconds
let statusReply = """
{"ok":true,"error":"","status":{"node":{"nodeId":"alice"},"neighbours":[
 {"peerId":"bob","passiveClient":false,"endpoints":[
   {"address":"10.10.0.3:57175","active":false,"metric":900},
   {"address":"bob.example.com","active":true,"metric":12034},
   {"address":"[fd00::3]:57175","active":true,"metric":31000}],
  "wireguard":{"latestHandshakeUnix":"1790376629000000000","txBytes":"10","rxBytes":"20"}},
 {"peerId":"carol","endpoints":[{"address":"10.10.0.5:57175","active":false,"metric":4294967295}],
  "wireguard":{"latestHandshakeUnix":"0"}},
 {"peerId":"dave","endpoints":[{"address":"10.10.0.7:57175","active":true,"metric":4294967295}],
  "wireguard":{"latestHandshakeUnix":"0"}},
 {"peerId":"phone","passiveClient":true,"endpoints":[],"wireguard":{"latestHandshakeUnix":"0"}},
 {"peerId":"laptop","passiveClient":true,"endpoints":[],"wireguard":{"latestHandshakeUnix":"1790376600000000000"}}
]}}
"""

@Test func readsPeers() {
    // bob: the lowest active endpoint (the inactive 900 doesn't count); carol: none active;
    // dave: active but no ping measured yet, so still INF; phone and laptop: passive clients, no endpoints
    #expect(readPeers(Data(statusReply.utf8)) == [
        "bob": Peer(metric: 12034, handshake: 1790376629),
        "carol": Peer(),
        "dave": Peer(),
        "phone": Peer(),
        "laptop": Peer(handshake: 1790376600),
    ])
}

// Printed by nylon's own encoder (protojson with EmitUnpopulated): a passive client's wireguard can be null
@Test func readsNylonsEncoding() {
    let reply = #"{"ok":true,"error":"","status":{"node":{"nodeId":"alice","interface":"","publicKey":"","listenPort":0,"configTimestamp":"0","traceEnabled":false,"advertised":[],"seqnos":[],"stats":null},"neighbours":[{"peerId":"bob","publicKey":"","passiveClient":false,"endpoints":[{"address":"bob.example.com","active":true,"remoteInit":false,"metric":12034,"filteredRttNs":"0","stabilizedRttNs":"0"}],"routes":[],"advertised":[],"wireguard":{"latestHandshakeUnix":"1790376629000000000","txBytes":"0","rxBytes":"0","persistentKeepaliveInterval":0}},{"peerId":"phone","publicKey":"","passiveClient":true,"endpoints":[],"routes":[],"advertised":[],"wireguard":null}],"routes":null,"feasibilityDistances":[]}}"#
    #expect(readPeers(Data(reply.utf8)) == ["bob": Peer(metric: 12034, handshake: 1790376629), "phone": Peer()])
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

@Test func rejectsFailedReplies() {
    #expect(readPeers(Data(#"{"ok":false,"error":"busy"}"#.utf8)) == nil)
    #expect(readPeers(Data("errno=22\n".utf8)) == nil) // what a plain WireGuard socket might say
}
