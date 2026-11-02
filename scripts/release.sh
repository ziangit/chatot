#!/bin/zsh
# Builds release assets and publishes a GitHub release: Chatot-<v>.zip (ad-hoc signed app), the VS Code .vsix,
# and chatot-chrome-extension-<v>.zip (extension + install.sh). Usage: scripts/release.sh 0.3.0 [notes-file]
set -euo pipefail
cd "$(dirname "$0")/.."
V=${1:?version}; NOTES=${2:-}
OUT="build/release-$V"; rm -rf "$OUT"; mkdir -p "$OUT"
./scripts/build-app.sh >/dev/null
# Ship an ad-hoc signed copy: a self-signed identity means nothing on another Mac, and the dev identity stays local.
cp -R build/Chatot.app "$OUT/Chatot.app"
codesign --force --deep --sign - "$OUT/Chatot.app" 2>/dev/null
(cd "$OUT" && ditto -c -k --keepParent Chatot.app "Chatot-$V.zip" && rm -rf Chatot.app)
(cd vscode-extension && rm -f *.vsix && npx --yes @vscode/vsce package >/dev/null && cp *.vsix "../$OUT/")
EXTV=$(python3 -c "import json;print(json.load(open('chrome-extension/manifest.json'))['version'])")
mkdir -p "$OUT/chrome"; cp -R chrome-extension/. "$OUT/chrome/"; cp scripts/install-chrome-extension.sh "$OUT/chrome/install.sh"; chmod +x "$OUT/chrome/install.sh" "$OUT/chrome/chrome-host.py"
(cd "$OUT" && ditto -c -k chrome "chatot-chrome-extension-$EXTV.zip" && rm -rf chrome)
ls -la "$OUT"
git tag -f "v$V" && git push -f origin "v$V"
if [ -n "$NOTES" ]; then gh release create "v$V" "$OUT"/* --title "Chatot $V" --notes-file "$NOTES"; else gh release create "v$V" "$OUT"/* --title "Chatot $V" --generate-notes; fi
