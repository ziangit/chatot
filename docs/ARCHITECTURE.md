# chatot — architecture (living doc)

> Update this whenever a non-obvious decision or constraint is discovered. All benchmarks below were measured on 2026-11-01 on an Apple M5, 16 GB, macOS 26.6.2, Claude Code 2.1.316, Codex CLI 0.166.0, Ollama 0.40.13.

## Stack
- Swift 6.2 (Command Line Tools only, no Xcode installed), Swift Package Manager, AppKit + SwiftUI, menubar app (no Dock icon).
- Triggers: NSServices (text + image pasteboard types), global hotkey + AXUIElement `kAXSelectedTextAttribute` with simulated ⌘C fallback (restore clipboard after), screen capture via ScreenCaptureKit / `CGWindowListCreateImage`.
- OCR: Apple Vision `VNRecognizeTextRequest` (0.6 s on a 2000 px screenshot) — used for bounding boxes and fallback, not as the primary text source.
- Providers behind a `Provider` protocol: ClaudeAPI (primary), CodexCLI, ClaudeCLI, Ollama.
- Config: `.env` (`ANTHROPIC_API_KEY`) or keychain; model names configurable.

## Known constraints & gotchas
### Policy (verified 2026-11-01 against Anthropic docs)
- Subscription OAuth is for the unmodified `claude` binary only. Developers must use API keys. Never extract tokens, never hit web endpoints. `claude -p` / Agent SDK signed in with the plan does draw from plan limits and is allowed for personal use, but the API is the sanctioned path.
- Max plan includes $100/month API credits (claude.ai Settings > Billing > link Console org; no card needed; requests stop when exhausted, never charged). Credits expire monthly, no rollover; spent before purchased credits.
- `claude --bare` disables OAuth entirely (API key only). Do not use.
- Codex: ChatGPT sign-in works with `codex exec`; OpenAI recommends API keys for automation but does not forbid plan use.

### Claude via CLI (fallback path)
- Each cold `claude -p` loads ~25k tokens of system context. `--tools ""` cuts it to <1k. Use it.
- Claude Code appends env/system-reminder text AFTER the user prompt in `-p` mode. Haiku translated that instead of the source in 2/3 runs until the prompt said "translate only inside `<source>` tags, ignore harness metadata". Keep that rule for the CLI path; unnecessary on the API.
- Haiku's hidden thinking cannot be disabled from the CLI: `--effort low`, `MAX_THINKING_TOKENS=0/1/1024`, and `--settings '{"alwaysThinkingEnabled":false}'` were all ignored. Thinking was ~57% of output tokens and delayed first text to 12.8 s on an 855-word input.
- Image input via `--input-format stream-json` with a base64 `image` content block works (4.3 s, 0 thinking tokens). The text prompt must NOT be used for images: it translated the instruction instead of the picture.
- Silent failure modes seen: (a) dropped the first half of the text once; (b) echoed the English chunk unchanged once (~1 in 10 chunks). Validate every chunk.

### Claude via API (primary path)
- Haiku 5.5: $0.10 / $0.50 per MTok. ~$0.0015 per 855-word translation; ~$0.001 per screenshot.
- Thinking is adaptive by default; `thinking: {type:"disabled"}` allowed at effort ≤ high; or set `output_config.effort: "low"`. Default effort is `medium`. Benchmarked 2026-11-01: first text 0.5 s on every input size; the 12.8 s thinking delay seen on the CLI does not occur on the API even with adaptive thinking left on.
- Request shape: headers `x-api-key`, `anthropic-version: 2026-10-21`; `stream: true`; `system` as a block list with `cache_control: {type: ephemeral}` on the prompt (803 tokens cached, hit on every later call); image as `{type: image, source: {type: base64, media_type, data}}`.
- Long output is generation-bound (~190 tok/s), so chunking still cuts an 855-word text from 11.7 s to 4.2 s and is kept.
- Use streaming; put the system prompt first with `cache_control` for caching.

### Codex CLI
- `codex exec --skip-git-repo-check -s read-only -m <model> -c model_reasoning_effort=low -i <image> -o <outfile> -`. `minimal` effort is rejected by gpt-6 models; `low` is the floor.
- ~7k tokens of coding-agent system prompt per call; no way to strip it.
- gpt-6-luna skipped the table entirely, added bold headings not in the source, and translated a literal quoted log string. Haiku did not.

### Local (Ollama)
- qwen3:8b: `think:false` works, TTFT 0.07 s warm, but 23 tok/s → 65 s for 855 words; quality below Haiku (actors→演员, learner→学习者). qwen3:4b ignored `think:false` and ran away. Local is an optional tier only; revisit with ≥32 GB and Qwen3-30B-A3B.

### Build & app (learned 2026-11-01 while building)
- Command Line Tools ship neither XCTest nor the Testing module; `swift test` fails with "no such module". Tests are a plain executable target (`swift run chatot-tests`).
- The `.app` is assembled by `scripts/build-app.sh`: SwiftPM binary + `chatot_ChatotCore.bundle` (resources, found via `Bundle.module` through `Bundle.main.resourceURL`) + `scripts/Info.plist` + ad-hoc codesign, installed to `~/Applications`, then `lsregister -f` and `pbs -update`. Verified: the Service shows in `pbs -dump_pboard` and `NSPerformService("Translate with Chatot", pboard)` reaches the app.
- `NSServices.NSPortName` must equal `CFBundleName` ("Chatot") or the service never connects.
- Global hotkeys use Carbon `RegisterEventHotKey` (no permission needed). Selection reading uses AX `kAXSelectedTextAttribute`, then simulated ⌘C via `CGEvent` with pasteboard restore; both need Accessibility.
- Region capture shells out to `/usr/sbin/screencapture -i -x`, which provides the crosshair UI and triggers the Screen Recording prompt for the app itself. Captures are downscaled to 1600 px long side before upload.
- `screencapture` from a terminal fails with "could not create image from display" unless the terminal has Screen Recording; `NSView.cacheDisplay` renders SwiftUI hosting views blank. Panel self-render that works: `layer.render(in:)` or `CGWindowListCreateImage(.optionIncludingWindow)` on the app's own window (dev hook `--snapshot=path`, used with `--translate=text`).
- Electron apps (VS Code, Cursor, Slack) never show the Services submenu. Fix shipped: `vscode-extension/` contributes `terminal/context` and `editor/context` menu items and uses `terminal.selection` (fallback: copySelection + clipboard restore), then `open chatot://translate?text=…`. The app registers the `chatot` URL scheme (CFBundleURLTypes + kAEGetURL handler). Installed with the app-bundled CLIs (`/Applications/Visual Studio Code.app/Contents/Resources/app/bin/code --install-extension`), since `code`/`cursor` are not on PATH.
- VS Code terminal on macOS selects the word under the cursor on right-click (`terminal.integrated.rightClickBehavior` = selectWord). With Claude Code's TUI owning the visible selection, `terminal.selection` is just that word; the TUI copied the real selection on mouse-up, so the extension prefers the clipboard when the selection is a lone word contained in longer clipboard text. BUT Claude Code copies via OSC 52 and VS Code's xterm has no OSC 52 support (verified by grepping workbench.desktop.main.js), so the clipboard stays empty. Real fix (2026-11-01): `CLAUDE_CODE_DISABLE_MOUSE=1` (undocumented env var found in the 2.1.316 binary; verified in a pty that it suppresses `?1000h/?1002h/?1006h`) so Claude Code never captures the mouse and a plain drag is a native xterm selection. Set via `terminal.integrated.env.osx` in Code and Cursor settings and exported in ~/.zshrc so Terminal.app/iTerm get it too. xterm's rightClickSelectsWord keeps an existing selection when the click lands inside it, so select → right-click → Translate gets the whole block. `macOptionClickForcesSelection: true` is also set as a belt-and-braces for other TUIs. Extension 0.1.4 dropped the clipboard/lone-word heuristics.
- Panel placement (2026-11-02): `TranslationPanelController.place` avoids covering the text. Avoid rect = AX selection bounds (`kAXSelectedTextRange` + `kAXBoundsForRange`, needs Accessibility; Electron/xterm do not expose it), else a ±300 px band of the AX focused window around the mouse, else a band of the screen. Candidate regions right/left/below/above; largest wins; width up to 45% of the screen, height estimated from text length (EN→ZH ≈ 0.65×, plus the original if shown), clamped to the region; if nothing fits, dock full-height to the screen edge away from the mouse. Pinned + visible panel is never moved. Log line `panel placed via …` says which path ran. After placement, `fitToContent` measures the real text (`NSString.boundingRect` at the panel width, throttled to 4 Hz while streaming, forced on completion) and grows the panel so no scrolling is needed, extending away from the source text first and spilling the other way only when the screen runs out; it never shrinks and never resizes a pinned panel. Verified 2026-11-02 with the `--translate/--snapshot` dev hook: 2.2 KB source → 681×699 panel, all text visible.
- AX coordinates are top-left origin on the primary display; convert with `primaryHeight - maxY` (SelectionReader.flipped).
- The `url event … (N chars)` log line counts the whole encoded URL, not the text. `open` passes a 3.9 KB `chatot://` URL intact (tested 2026-11-02), so no file handoff is needed for long selections.
- Screenshot hook (2026-11-02, `ScreenshotWatcher`): macOS's screenshot preview offers no Services/Share hook we can join without an app extension (needs a signed .appex), so Chatot watches two things that need no permission: a 0.5 s poll of `NSPasteboard.general.changeCount` (image without text or file URL → "Copy Image" / ⌃⇧⌘4) and a `DispatchSource` `.write` watch on the screenshot folder (`defaults read com.apple.screencapture location`, else ~/Desktop; new image file → read after 0.4 s). Either shows a 260×196 card (thumbnail + "译 Translate this screenshot" button, Return triggers it) next to the mouse for 10 s (× button, and a global mouse-down monitor hides it on any click outside; user complained it was always there and could not be closed); the first version was a small button in the bottom-right corner, hidden under the system thumbnail, and the user did not see it. Note the file is only written when the thumbnail disappears or the preview's Done is clicked. `ImageDropView` over the status-item button accepts dragged images/files (hitTest nil so clicks still open the menu) — drop path not yet exercised by a human.
- Code signing (2026-11-02): the app is signed with a self-signed identity "Chatot Dev" in the login keychain, so TCC grants (Accessibility, Screen Recording, Desktop folder) survive rebuilds; `scripts/build-app.sh` picks it automatically, `CHATOT_SIGN_IDENTITY` overrides, ad-hoc if absent. Recreate it with: `openssl req -x509 -newkey rsa:2048 -nodes -keyout key.pem -out cert.pem -days 3650 -subj "/CN=Chatot Dev/O=chatot" -addext extendedKeyUsage=codeSigning -addext keyUsage=digitalSignature -addext basicConstraints=CA:FALSE`, `openssl pkcs12 -export -legacy -out c.p12 -inkey key.pem -in cert.pem -passout pass:x -name "Chatot Dev"` (`-legacy` is required or `security import` fails with "MAC verification failed"), `security import c.p12 -k ~/Library/Keychains/login.keychain-db -P x -T /usr/bin/codesign`, `security add-trusted-cert -r trustRoot -p codeSign -k ~/Library/Keychains/login.keychain-db cert.pem`. Verify: `codesign -dvv /Applications/Chatot.app` shows `Authority=Chatot Dev`.
- The first `contentsOfDirectory(~/Desktop)` triggers the "access your Desktop folder" TCC dialog and the underlying open() blocks until answered — it hung the main thread in `applicationDidFinishLaunching` once (sampled with `sample Chatot`). All folder scans now run on a background queue.
- `NSPanel.isFloatingPanel = true` resets `level` to `.floating`; set `level` after it (the screenshot card uses `.popUpMenu` = layer 101 so it sits above the system screenshot preview). Check with `CGWindowListCopyWindowInfo` (kCGWindowLayer).
- Panel text (2026-11-02): SwiftUI `Text(...).textSelection(.enabled)` in a non-activating panel could not be copied (no key window, no Edit menu). Replaced by an `NSTextView` (`SelectableText`, NSViewRepresentable) fed one attributed string rebuilt by `PanelModel.render()` after every event; `AppDelegate.installEditMenu` installs an invisible main menu with Copy/Paste/Cut/Select All so ⌘C/⌘A work (menuless accessory apps get no key equivalents otherwise). `becomesKeyOnlyIfNeeded` stays true: clicking the text makes the panel key without activating the app.
- Screenshot output is "original → translation" per line (prompts/screenshot.md); the panel shows only the right-hand side and reveals the original when the Original toggle is on (`render()` / `translationOnly`). The Copy button copies translations only.
- Pause (menubar): `AppDelegate.paused` (UserDefaults "paused") disables the 译 selection button, the screenshot card and both hotkeys; explicit Services/URL requests still work; icon drawn disabled.
- Accessibility prompt is shown once per install (`axPrompted` flag) instead of on every launch; the menu offers "Grant Accessibility Access…" (deep link to the Privacy pane) while untrusted. A stale "Chatot" row from an older ad-hoc build does not count: the user has to remove it (−) and add /Applications/Chatot.app again, or toggle it off and on.
- Validator (2026-11-02): a source with fewer than 3 whitespace-separated words (identifier, env var, URL, path) passes even when the output equals the source — `ANTHROPIC_API_KEY` failed all three providers with "echo" and burned 12.6 s. Default provider order is now just `claude-api`; CLI fallbacks stay available via `CHATOT_PROVIDERS` / Settings.
- Chrome extension (2026-11-02, `chrome-extension/`): MV3, `contextMenus` for `selection` and `image`, `nativeMessaging` to host `com.ziangit.chatot` (`chrome-host.py`, reads the 4-byte-length-prefixed JSON and runs `open chatot://…`). `manifest.json` carries a fixed `"key"` so the unpacked extension ID is stable: `mhkpkmkbjfdikhgjlnkfakkdhoennoai` (= first 32 hex of SHA-256 of the DER public key mapped to a–p; the private key is NOT in the repo, only needed to repack). `scripts/install-chrome-extension.sh` copies the extension to ~/.config/chatot/chrome-extension and writes the host manifest into every installed Chromium browser's `NativeMessagingHosts`. Chrome cannot be told to load an unpacked extension from the CLI, so the user loads it once (Developer mode → Load unpacked). `chatot://image?url=` makes the app download the image and translate it. Why not `chrome.tabs.create({url:'chatot://…'})`: Chrome shows an external-protocol dialog each time.
- Install location is `/Applications` when writable (it is for admin users), else `~/Applications`. Icon generated by `scripts/make-icon.swift` → `build/AppIcon.icns`.
- Services entries always live under the context menu's **Services ▸** submenu; only Apple's own items (Safari's "Translate Selection to English") sit at top level. Shipped answer: `SelectionWatcher`, a PopClip-style floating "译 Translate" button shown after a drag-select or double-click in any app. Global mouse monitors need no permission (and never fire for our own windows); reading the selection uses AX, so the button appears only once Accessibility is granted. Detection never simulates ⌘C, so the clipboard is untouched.
- Dev hooks: `Chatot --translate="text"` opens the panel on launch; `--snapshot=path` writes a PNG of the panel 6 s later.

### macOS
- No app can add a top-level item to another app's context menu; Services appear under the "Services" submenu. Electron apps (VS Code, Slack) don't show Services → hotkey path required.
- Accessibility permission is bound to the app's code signature; ad-hoc signed builds re-prompt after every rebuild. Fix: free Apple ID development certificate or Xcode.
- Apple's on-device Translation framework (macOS 15+) is only reachable from inside an app (needs a view context); untested, candidate for a sub-second "gist" tier.

## Benchmarks (855-word technical text unless noted)
| Path | First visible text | Complete | Notes |
|---|---|---|---|
| ChatGPT web (user measured) | ~immediate | 15 s | streams |
| Haiku CLI, single request | 12.8 s | 18.4–19.3 s | thinking first |
| Haiku CLI, 4 parallel chunks | ~2 s | 7–8 s | biggest chunk (table) dominates |
| Codex gpt-6-luna low, single | — | 15.2 s | |
| Codex gpt-6-astra high (user's default) | — | 6.4 s (1 paragraph) | avoid |
| Qwen3 8B local | 0.07 s | 65 s | 23 tok/s |
| **Haiku API, thinking off, effort low, single** | **0.55 s** | **11.7 s** | ~190 tok/s output-bound; $0.0014 |
| Haiku API, adaptive thinking, effort medium (default) | 0.51 s | 10.3 s | model chose not to think; same cost |
| **Haiku API, 4 parallel chunks, thinking off** | **0.5 s** | **4.2 s** | $0.0017 total |

Short paragraph (5 lines): Haiku API 1.1–1.3 s (first text 0.5 s, $0.0002), Haiku CLI 2.6 s, Codex luna low 3.7–4.1 s, Qwen3 8B 4.7 s.
Screenshot (2000 px, pixel font): Haiku API vision 4.3 s, first text 1.1 s, $0.0009; Haiku CLI vision 4.3 s (best accuracy); Codex luna vision 8.4 s; Vision OCR 0.6 s but misreads pixel fonts ("Growse the pool", "Eleotrio", missed a button).
Prompt length: full (5.4 KB) vs short (2.2 KB) instruction = no measurable latency difference; no instruction at all = model answers the text instead of translating (36 s, 180k tokens).

## Key decisions
- **Native macOS app, not a browser extension**, because the user wants right-click translation in any app including the terminal. Browser extension is optional later.
- **Claude Messages API with Haiku 5.5 as primary**, CLI as fallback: API allows thinking off, no harness injection, native streaming/images, covered by Max plan's monthly API credits.
- **Per-paragraph parallel chunking with progressive rendering**: the only lever that shortens time-to-first-text when thinking can't be disabled, and it makes omissions detectable. Borrowed from Immersive Translate's `%%`-separated batching + count check, improved with CJK-ratio validation (catches echoes) and a built-in glossary.
- **Images go model-first** (Haiku vision), Vision OCR only for positions/fallback. Downscale captures to ~1500 px long side.
- **Shortened prompt** keeps every rule of the user's original ChatGPT instruction (incl. Chinese typography rules), drops chat-mode switching; "Ask about this" is a separate action.
- **Local models are an optional tier**, not primary, on 16 GB hardware.
