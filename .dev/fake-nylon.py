#!/usr/bin/env python3
# Fake nylon IPC socket for trying the menu app: answers `nylon status` requests with random latencies.
# Peers match .dev/central.yaml. Run: python3 .dev/fake-nylon.py [folder]   (default /tmp/fake-nylon)
# then start the app with -socket-dir pointing at that folder. You own this socket, so the app doesn't ask for admin.
import json
import os
import random
import socket
import sys
import time

INF = 2**32 - 1
# peer -> {endpoint: usual ping in µs}. phone and laptop are passive clients (central.yaml `clients`), which nylon
# never measures: laptop is online ("connected"), phone never connected ("offline"). alice is this device, so no peer.
PEERS = {
    "bob": {"10.10.0.2:57175": 1800, "bob.example.com": 24000},  # same LAN, and over the internet
    "carol": {"10.10.0.3:57175": 2500},
    "relay": {"10.10.0.9:57175": 38000},  # another city
    "phone": {},
    "laptop": {},
}


def status():
    neighbours = []
    for peer, endpoints in PEERS.items():
        handshake = 0 if peer == "phone" else time.time_ns() - random.randint(5, 100) * 10**9
        eps = []
        for address, usual in endpoints.items():
            active = random.random() > 0.05  # 1 in 20 can't connect, so an endpoint drops now and then
            metric = int(usual * random.uniform(0.9, 1.1)) if active else INF  # ±10% jitter
            eps.append({"address": address, "active": active, "metric": metric})
        # protojson writes int64 as a string
        neighbours.append({"peerId": peer, "endpoints": eps, "wireguard": {"latestHandshakeUnix": str(handshake)}})
    return {"ok": True, "error": "", "status": {"node": {"nodeId": "alice"}, "neighbours": neighbours}}


folder = sys.argv[1] if len(sys.argv) > 1 else "/tmp/fake-nylon"
os.makedirs(folder, exist_ok=True)
path = os.path.join(folder, "utun9.sock")
if os.path.exists(path):
    os.remove(path)
server = socket.socket(socket.AF_UNIX, socket.SOCK_STREAM)
server.bind(path)
server.listen()
print(f"fake nylon socket at {path}")
while True:
    conn, _ = server.accept()
    with conn, conn.makefile("rb") as f:
        if f.readline() == b"get=nylon\n" and f.readline():
            conn.sendall((json.dumps(status()) + "\n").encode())
