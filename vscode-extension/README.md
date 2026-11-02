# Chatot Translate (VS Code / Cursor)

Adds **Translate with Chatot** (使用 Chatot 翻译) to the integrated terminal's and the editor's right-click menus. The selection is sent to the Chatot macOS app via the `chatot://translate` URL scheme. Requires `/Applications/Chatot.app`.

For the Claude Code terminal, set `CLAUDE_CODE_DISABLE_ALTERNATE_SCREEN=1` first (see the main README) so drag-select works.

Build and install:

```
cd vscode-extension
npx --yes @vscode/vsce package
code --install-extension chatot-vscode-0.2.1.vsix      # VS Code
cursor --install-extension chatot-vscode-0.2.1.vsix    # Cursor
```
Reload the window afterwards.
