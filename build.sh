#!/bin/bash
set -euo pipefail
cd -- "$(dirname -- "$0")"
if [[ "$(uname -s)" != Darwin ]]; then
  echo 'This build requires a macOS runner with Xcode command line tools.' >&2
  exit 1
fi
command -v xcrun >/dev/null
SDK="$(xcrun --sdk macosx --show-sdk-path)"
# Unique output: existing releases are never deleted or overwritten.
OUTPUT="$(mktemp -d "$PWD/build-XXXXXXXX")"
APP="$OUTPUT/FC Teugn Miniticker.app"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources" "$OUTPUT/Club.iconset"
cp Info.plist "$APP/Contents/Info.plist"
plutil -lint "$APP/Contents/Info.plist"
xcrun swiftc -swift-version 5 -sdk "$SDK" Sources/Policy.swift Tests/main.swift -o "$OUTPUT/policy-tests"
"$OUTPUT/policy-tests"
for ARCH in arm64 x86_64; do
  xcrun swiftc -swift-version 5 -O -sdk "$SDK" -target "$ARCH-apple-macosx13.0" \
    -framework AppKit -framework WebKit Sources/Policy.swift Sources/main.swift -o "$OUTPUT/ticker-$ARCH"
done
lipo -create "$OUTPUT/ticker-arm64" "$OUTPUT/ticker-x86_64" -output "$APP/Contents/MacOS/FCTeugnMiniticker"
lipo -verify_arch arm64 x86_64 "$APP/Contents/MacOS/FCTeugnMiniticker"
for SIZE in 16 32 128 256 512; do
  sips -z "$SIZE" "$SIZE" Club.png --out "$OUTPUT/Club.iconset/icon_${SIZE}x${SIZE}.png" >/dev/null
  DOUBLE=$((SIZE * 2))
  sips -z "$DOUBLE" "$DOUBLE" Club.png --out "$OUTPUT/Club.iconset/icon_${SIZE}x${SIZE}@2x.png" >/dev/null
done
iconutil -c icns "$OUTPUT/Club.iconset" -o "$APP/Contents/Resources/Club.icns"
# Local ad-hoc integrity signature only. This is not a Developer ID signature
# and does not claim Gatekeeper approval or Apple notarization.
codesign --force --sign - "$APP"
codesign --verify --deep --strict --verbose=2 "$APP"
ZIP="$OUTPUT/FC-Teugn-Miniticker-0.1.0-mac-universal-TEST.zip"
ditto -c -k --sequesterRsrc --keepParent "$APP" "$ZIP"
shasum -a 256 "$ZIP" > "$OUTPUT/SHA256.txt"
printf '\nMac test artifact: %s\n' "$ZIP"
if [[ -n "${GITHUB_OUTPUT:-}" ]]; then printf 'directory=%s\n' "$OUTPUT" >> "$GITHUB_OUTPUT"; fi
