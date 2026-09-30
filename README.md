# Nylon Mac App

A menu bar app that lists the nodes in your [nylon](https://github.com/encodeous/nylon) network with their IPs, and, for each peer, its latency in ms (the best metric `nylon status` shows), "connected" when it's online without a measured latency (like a phone), or "offline". Click a node to copy its IP.

## Run it

1. Install the Command Line Tools if you don't have them: `xcode-select --install`
2. From this folder, build and start it:

   ```bash
   swift build -c release && .build/release/NylonApp
   ```

3. Click the network icon in the menu bar, then "Choose central.yaml…" and pick your file. The app remembers it for next time.

4. For latency, turn on nylon's metrics endpoint. Add this to `node.yaml` and restart nylon:

   ```yaml
   observability_addr: 127.0.0.1:9090
   ```

   Without it the menu says "Not running". The app doesn't need root.

To skip the picker, pass the file: `.build/release/NylonApp -central /path/to/central.yaml`. With no file chosen, it reads `central.yaml` in the current directory, like `nylon run`. If nylon serves metrics somewhere else, pass `-metrics http://127.0.0.1:<port>/metrics`.

## Test

```bash
swift test -Xswiftc -plugin-path -Xswiftc "$(xcode-select -p)/usr/lib/swift/host/plugins/testing"
```

The `-plugin-path` flag is only needed without full Xcode.
