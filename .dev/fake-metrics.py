#!/usr/bin/env python3
# Fake nylon /metrics for testing the menu app: random endpoint metrics on every request.
# Peers match .dev/central.yaml. Run: python3 .dev/fake-metrics.py [port]   (default 9091)
import random
import sys
import time
from http.server import BaseHTTPRequestHandler, HTTPServer

INF = 2**32 - 1
# peer -> {endpoint: its usual ping in microseconds (nylon's metric unit)}. phone and laptop are passive clients, so
# they have no endpoints: laptop is online (recent handshake, shows "connected"), phone never connected ("offline").
# alice is left out as this device: nylon doesn't list itself as a peer.
PEERS = {
    "bob": {"10.10.0.2:57175": 1800, "bob.example.com": 24000},  # same LAN, and over the internet
    "carol": {"10.10.0.3:57175": 2500},
    "relay": {"10.10.0.9:57175": 38000},  # another city
    "phone": {},
    "laptop": {},
}


def metrics():
    lines = ["# HELP nylon_up Whether the nylon daemon is ready.", "# TYPE nylon_up gauge", "nylon_up 1"]
    for peer, endpoints in PEERS.items():
        handshake = 0 if peer == "phone" else int(time.time()) - random.randint(5, 100)
        lines.append(f'nylon_wireguard_peer_latest_handshake_seconds{{peer="{peer}"}} {handshake}')
        for ep, usual in endpoints.items():
            active = random.random() > 0.05  # 1 in 20 can't connect, so INF shows up now and then
            metric = int(usual * random.uniform(0.9, 1.1)) if active else INF  # ±10% jitter
            labels = f'endpoint="{ep}",peer="{peer}"'
            lines.append(f"nylon_endpoint_active{{{labels}}} {int(active)}")
            lines.append(f"nylon_endpoint_metric{{{labels}}} {metric}")
    return "\n".join(lines) + "\n"


class Handler(BaseHTTPRequestHandler):
    def do_GET(self):
        if self.path != "/metrics":
            self.send_error(404)
            return
        body = metrics().encode()
        self.send_response(200)
        self.send_header("Content-Type", "text/plain; version=0.0.4; charset=utf-8")
        self.send_header("Content-Length", str(len(body)))
        self.end_headers()
        self.wfile.write(body)


port = int(sys.argv[1]) if len(sys.argv) > 1 else 9091
print(f"fake nylon metrics on http://127.0.0.1:{port}/metrics")
HTTPServer(("127.0.0.1", port), Handler).serve_forever()
