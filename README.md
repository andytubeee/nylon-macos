# Nylon Mac App

A menu bar app that lists the nodes in your [nylon](https://github.com/encodeous/nylon) network.

## Install

For Apple Silicon Macs on macOS 14 or later.

1. Open `Nylon.dmg` and drag Nylon onto Applications.
2. Open Nylon. Apple hasn't notarized the app, so macOS blocks it the first time. Go to System Settings → Privacy & Security, find "Nylon was blocked", and click Open Anyway. Or clear the block from a terminal:

   ```bash
   xattr -dr com.apple.quarantine /Applications/Nylon.app
   ```

3. Nylon opens its Settings window the first time. Click "Choose…" and pick your `central.yaml`. The app remembers it. To change it later, click the nylon icon in the menu bar, then "Settings…".

4. nylon's status socket, the one `nylon status` uses, is root only. While nylon is running, Nylon opens System Settings → General → Login Items so you can allow its helper once. The helper runs as root, passes on nylon's status and nothing else, and only answers Nylon itself. If you skip it, the menu offers "Allow Access…".

`Packaging/package.sh` builds the DMG and writes it to `dist/Nylon.dmg`. Set `SIGN_ID` to sign with a certificate from your keychain, otherwise it's signed ad hoc.

## Run it from source

1. Install the Command Line Tools if you don't have them: `xcode-select --install`
2. From this folder, build and start it:

   ```bash
   swift build -c release && .build/release/Nylon
   ```

3. Follow step 3 of Install. A build run from `.build/` isn't an app bundle, so it can't install the helper. To read a real nylon from it, give your user access to nylon's socket (redo this after nylon restarts, since the socket's name changes):

   ```bash
   sudo chmod +a "$(whoami) allow write" /var/run/wireguard/utun*.sock
   ```

To skip Settings, pass the file: `.build/release/Nylon -central /path/to/central.yaml`. With no file chosen, it reads `central.yaml` in the current directory, like `nylon run`.

## Try it without nylon

`.dev/` has a fake network and a fake nylon socket that returns new latencies on every request. You own that socket, so there's no admin prompt. From this folder, in two terminals:

```bash
python3 .dev/fake-nylon.py
```

```bash
.dev/run.sh .dev/central.yaml -socket-dir /tmp/fake-nylon
```

## Test

```bash
swift test -Xswiftc -plugin-path -Xswiftc "$(xcode-select -p)/usr/lib/swift/host/plugins/testing"
```

The `-plugin-path` flag is only needed without full Xcode.
