# chatot

System-wide translator for macOS. Select text in any app (terminal included), right-click → Services → **Translate with Chatot**, or press **⌥⌘T**. Press **⌥⌘R** to drag a screen region and translate the text in it, screenshots and images included. The translation streams into a floating panel next to the cursor.

Runs on Claude Haiku 5.5 through the Anthropic API (covered by the Max plan's monthly API credits), with the Codex CLI (ChatGPT login) and Claude CLI as fallbacks and Ollama as an optional offline tier.

## Build and install

```
cp .env.example .env            # put ANTHROPIC_API_KEY in it
./scripts/build-app.sh          # builds, signs ad hoc, installs ~/Applications/Chatot.app, registers the Service
open ~/Applications/Chatot.app
```

First use of ⌥⌘T asks for Accessibility permission; first use of ⌥⌘R asks for Screen Recording. Both prompts come from macOS. After an ad-hoc rebuild the Accessibility grant may need to be re-done (set `CHATOT_SIGN_IDENTITY` to a developer certificate to avoid that).

## Develop

```
swift build
swift run chatot-cli translate "Some English text"     # end-to-end through the real providers
swift run chatot-cli image path/to/screenshot.png
swift run chatot-cli providers
swift run chatot-tests                                   # unit tests (no XCTest on Command Line Tools)
```

Settings live in the menubar app (target language, provider order, models, API key in keychain). Glossary: `~/.config/chatot/glossary.txt` with `term = translation` lines. Log: `~/Library/Logs/chatot.log`.

See `docs/ARCHITECTURE.md` for benchmarks and gotchas, `session-handoff.md` for status.
