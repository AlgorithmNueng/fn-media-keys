#!/bin/bash
# Builds mediakeys into "Fn Media Keys.app". The bundle gives the app its own identity for the
# Accessibility / Input Monitoring permissions. Ad-hoc signing (the default) changes the identity on
# every rebuild, so those permissions must be granted again; a stable SIGN_ID (the name of a
# self-signed code-signing certificate) avoids that.
set -euo pipefail

cd "$(dirname "${BASH_SOURCE[0]}")/.."

swift build -c release --product mediakeys
BIN="$(swift build -c release --show-bin-path)/mediakeys"

APP="${APP_DIR:-$HOME/Applications}/Fn Media Keys.app"
[[ "$APP" == *.app ]] || { echo "refusing to touch '$APP': not an .app path" >&2; exit 1; }

# Match only the installed bundle's executable, so the dev CLI (.build/.../mediakeys) keeps running.
pkill -f "$APP/Contents/MacOS/mediakeys" || true

rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp "$BIN" "$APP/Contents/MacOS/mediakeys"
cp scripts/Info.plist "$APP/Contents/Info.plist"
cp scripts/AppIcon.icns "$APP/Contents/Resources/AppIcon.icns"

codesign --force --options runtime --sign "${SIGN_ID:--}" "$APP"
codesign --verify --strict "$APP"

[[ "${NO_OPEN:-}" == 1 ]] || open "$APP"
