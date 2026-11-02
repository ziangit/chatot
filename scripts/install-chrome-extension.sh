#!/bin/bash
# Copies the Chrome extension to a stable path and registers the native-messaging host for Chrome.
# After this, load it once: chrome://extensions → Developer mode → Load unpacked → ~/.config/chatot/chrome-extension
set -euo pipefail
SRC="$(cd "$(dirname "$0")/.." && pwd)/chrome-extension"
DST="$HOME/.config/chatot/chrome-extension"
mkdir -p "$DST"
cp "$SRC"/manifest.json "$SRC"/background.js "$SRC"/icon.png "$SRC"/chrome-host.py "$DST"/
chmod +x "$DST/chrome-host.py"
EXT_ID="mhkpkmkbjfdikhgjlnkfakkdhoennoai"   # fixed by the "key" in manifest.json
for BROWSER in "Google/Chrome" "Google/Chrome Canary" "Chromium" "BraveSoftware/Brave-Browser" "Microsoft Edge" "Arc/User Data"; do
  DIR="$HOME/Library/Application Support/$BROWSER"
  [ -d "$DIR" ] || continue
  mkdir -p "$DIR/NativeMessagingHosts"
  cat > "$DIR/NativeMessagingHosts/com.ziangit.chatot.json" <<JSON
{
  "name": "com.ziangit.chatot",
  "description": "Chatot translation bridge",
  "path": "$DST/chrome-host.py",
  "type": "stdio",
  "allowed_origins": ["chrome-extension://$EXT_ID/"]
}
JSON
  echo "registered host for $BROWSER"
done
echo "extension at $DST — load it once via chrome://extensions (Developer mode → Load unpacked)"
