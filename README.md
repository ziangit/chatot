# chatot

System-wide translator for macOS. Select text in any app (terminal included) and click the floating **译 Translate** button that appears, press **⌥⌘T**, or right-click → Services → **Translate with Chatot** (native apps only; in VS Code/Cursor the bundled extension adds the menu item). Press **⌥⌘R** to drag a screen region and translate the text in it, screenshots and images included. The translation streams into a floating panel next to the cursor.

Runs on Claude Haiku 5.5 through the Anthropic API (covered by the Max plan's monthly API credits). ChatGPT (OpenAI API) and DeepSeek can be selected in Settings instead. UI in English or Simplified Chinese.

## Build and install

```
cp .env.example .env            # put ANTHROPIC_API_KEY in it
./scripts/build-app.sh          # builds, signs ad hoc, installs /Applications/Chatot.app, registers the Service
open /Applications/Chatot.app
```

On first launch the app asks for Accessibility permission (needed by the selection button and ⌥⌘T); first use of ⌥⌘R asks for Screen Recording. Both prompts come from macOS. After an ad-hoc rebuild the Accessibility grant may need to be re-done (set `CHATOT_SIGN_IDENTITY` to a developer certificate to avoid that).

## VS Code / Cursor

Electron apps draw their own context menus, so the macOS Services entry never appears there. The `vscode-extension/` folder adds **Translate with Chatot** to the integrated terminal and editor right-click menus (and ⌥⌘T inside the editor). See `vscode-extension/README.md` to build and install; it talks to the app through the `chatot://translate?text=…` URL scheme, which any other tool can use too (`chatot://region`, `chatot://clipboard`, `chatot://selection`).

## Develop

```
swift build
swift run chatot-cli translate "Some English text"     # end-to-end through the real providers
swift run chatot-cli image path/to/screenshot.png
swift run chatot-cli providers
swift run chatot-tests                                   # unit tests (no XCTest on Command Line Tools)
```

Settings live in the menubar app (language, target language, provider, model, API key in keychain). Glossary: `~/.config/chatot/glossary.txt` with `term = translation` lines. Log: `~/Library/Logs/chatot.log`.

See `docs/ARCHITECTURE.md` for benchmarks and gotchas, `session-handoff.md` for status.

## Chrome
`scripts/install-chrome-extension.sh` registers the native-messaging bridge; then load `~/.config/chatot/chrome-extension` once via chrome://extensions (Developer mode → Load unpacked). Right-click → "Translate with Chatot" appears at the top level for selected text and images.
