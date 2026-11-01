# Chatot Translate (VS Code / Cursor)

Adds **Translate with Chatot** to the integrated terminal's and the editor's right-click menus, and binds ⌥⌘T inside VS Code. The selection is sent to the Chatot macOS app (`/Applications/Chatot.app`) via the `chatot://translate` URL scheme.

Build and install:

```
cd vscode-extension
npx --yes @vscode/vsce package --allow-missing-repository
code --install-extension chatot-vscode-0.1.0.vsix      # VS Code
cursor --install-extension chatot-vscode-0.1.0.vsix    # Cursor
```
Reload the window afterwards.
