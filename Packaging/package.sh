#!/bin/sh
# Builds dist/Nylon.dmg: Nylon.app next to an Applications shortcut to drag it onto.
set -eu
cd "$(dirname "$0")/.."

swift build -c release
bin=.build/release

stage=dist/dmg # what the DMG shows: the app and a shortcut to Applications
app=$stage/Nylon.app
rm -rf dist
mkdir -p "$app/Contents/MacOS" "$app/Contents/Resources"
cp "$bin/Nylon" "$app/Contents/MacOS/"
cp -R "$bin/Nylon_NylonApp.bundle" "$app/Contents/Resources/" # the menu bar icons
cp Packaging/Info.plist "$app/Contents/"
mkdir -p "$app/Contents/Library/LaunchDaemons" # where SMAppService looks for the helper's launchd plist
cp Packaging/com.encodeous.nylon-macos.helper.plist "$app/Contents/Library/LaunchDaemons/"

# AppIcon.icns from AppIcon.svg (a copy of nylon's docs/assets/logo_neutral.svg): each size macOS asks for,
# drawn at 80% so it has the margin other app icons have
iconset=dist/AppIcon.iconset
mkdir "$iconset"
for size in 16 32 128 256 512; do
    for scale in 1 2; do
        px=$((size * scale))
        png=$iconset/icon_${size}x${size}$([ $scale = 2 ] && echo @2x || true).png
        sips -s format png -z $((px * 8 / 10)) $((px * 8 / 10)) Packaging/AppIcon.svg --out "$png" >/dev/null
        sips -p $px $px "$png" >/dev/null
    done
done
iconutil -c icns "$iconset" -o "$app/Contents/Resources/AppIcon.icns"

# Signed with SIGN_ID (a Developer ID or another certificate in the keychain) if set, else ad hoc.
# Not notarized, so the first launch needs "Open Anyway" in System Settings.
codesign --force --options runtime --sign "${SIGN_ID:--}" "$app"

ln -s /Applications "$stage/Applications"
hdiutil create -volname Nylon -srcfolder "$stage" -format UDZO dist/Nylon.dmg
rm -r "$stage" "$iconset"
