#!/bin/zsh
# Builds Chatot.app from the SwiftPM products, signs it ad hoc, installs to ~/Applications, registers the Service.
set -euo pipefail
cd "$(dirname "$0")/.."
CONFIG=${1:-release}
swift build -c "$CONFIG" --product Chatot 2>&1 | grep -E "error|warning: var|Compiling|Build complete" | tail -5 || true
BIN=".build/$CONFIG"
APP="build/Chatot.app"
rm -rf "$APP"; mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp "$BIN/Chatot" "$APP/Contents/MacOS/Chatot"
cp -R "$BIN/chatot_ChatotCore.bundle" "$APP/Contents/Resources/"
cp scripts/Info.plist "$APP/Contents/Info.plist"
if [[ ! -f build/AppIcon.icns || scripts/make-icon.swift -nt build/AppIcon.icns ]]; then swift scripts/make-icon.swift build/AppIcon.icns build/MenuIcon.png build/MenuIcon@2x.png; fi
cp build/AppIcon.icns "$APP/Contents/Resources/AppIcon.icns"
cp build/MenuIcon.png build/MenuIcon@2x.png "$APP/Contents/Resources/"
cp -R scripts/lproj/*.lproj "$APP/Contents/Resources/"
echo -n "APPL????" > "$APP/Contents/PkgInfo"
# Ad-hoc signature (Accessibility permission is tied to it; a dev certificate avoids re-prompts after rebuilds).
# Prefer a stable identity so macOS keeps Accessibility / Screen Recording / Desktop grants across rebuilds.
# "Chatot Dev" is a self-signed code-signing cert in the login keychain (see docs/ARCHITECTURE.md); ad-hoc otherwise.
if [ -z "${CHATOT_SIGN_IDENTITY:-}" ] && security find-identity -v -p codesigning 2>/dev/null | grep -q '"Chatot Dev"'; then
  CHATOT_SIGN_IDENTITY="Chatot Dev"
fi
codesign --force --deep --sign "${CHATOT_SIGN_IDENTITY:--}" "$APP" 2>&1 | grep -v "replacing existing signature" || true
# Install for the user and register with Launch Services + the Services menu.
if [[ -w /Applications ]]; then DEST="/Applications/Chatot.app"; else DEST="$HOME/Applications/Chatot.app"; mkdir -p "$HOME/Applications"; fi
rm -rf "$HOME/Applications/Chatot.app" 2>/dev/null || true
if pgrep -x Chatot >/dev/null; then pkill -x Chatot; sleep 0.5; fi
rm -rf "$DEST"; cp -R "$APP" "$DEST"
/System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister -f "$DEST" >/dev/null 2>&1 || true
/System/Library/CoreServices/pbs -update >/dev/null 2>&1 || true
# Seed the user config dir with the repo .env once, so the installed app finds the key without the repo.
mkdir -p "$HOME/.config/chatot"
if [[ -f .env && ! -f "$HOME/.config/chatot/.env" ]]; then cp .env "$HOME/.config/chatot/.env"; chmod 600 "$HOME/.config/chatot/.env"; echo "copied .env to ~/.config/chatot/.env"; fi
echo "installed $DEST"
