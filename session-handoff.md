# Session handoff

**Current phase:** v0.2 — scope reset to exactly the user's asks (2026-11-02). All installed, relaunched, pushed.
**Next concrete step:** User exercises the four remaining paths and reports: (1) right-click in the Claude Code terminal → Translate with Chatot; (2) right-click in Chrome → Translate with Chatot / Translate image with Chatot; (3) right-click in a native app → Services ▸ Translate with Chatot; (4) take a screenshot → card → click. Then stop adding features unless asked.

## UX rules from the user (non-negotiable)
- "I just want select, right click, and translate." No modifier keys, no "press ⌘C first", no hints telling the user to do something different.
- 2026-11-02: "how many functions are not asked by me? Just keep my intended function." Do not add features, menu items, hotkeys, fallbacks or prompts that were not requested. Claude API only.

## What exists now
- Chatot.app (menubar: Pause / Settings / Quit). Triggers: Services item (text + image), `chatot://translate?text=` and `chatot://image?url=` URL scheme, screenshot card (clipboard image or new file in the screenshot folder).
- Panel: placed off the selection (mouse band), grows with content, native text view (select, ⌘C, Original toggle, Copy, Close), screenshot output shows translations only.
- VS Code/Cursor extension 0.2.0 (`vscode-extension/`): terminal/editor right-click items only.
- Chrome extension (`chrome-extension/`, loaded unpacked by the user, ID mhkpkmkbjfdikhgjlnkfakkdhoennoai) + native-messaging host registered for Chrome/Chromium/Brave/Edge/Arc.
- Core: Chunker, Validator (lenient for short labels/names; CJK→English auto-detect), Glossary, ClaudeAPIProvider only. Tests: `swift run chatot-tests`.

## State of the user's machine (not visible in the repo)
- App signed with the self-signed identity "Chatot Dev" (login keychain) so TCC grants persist. Only permission needed now: Desktop folder access for the screenshot watcher (already granted). Accessibility and Screen Recording are no longer used.
- `CLAUDE_CODE_DISABLE_ALTERNATE_SCREEN=1` in Code/Cursor `terminal.integrated.env.osx` and ~/.zshrc (classic Claude Code renderer: wheel scrolls history, mouse not captured, so plain drag-select works). `macOptionClickForcesSelection: true` also set. New terminal + new `claude` needed after changes.
- `~/.config/chatot/.env` holds the API key copy; `~/.config/chatot/chrome-extension` is the loaded Chrome extension path.
- Ollama + qwen3 models still installed from benchmarking; unused, can be removed.

## History (2026-11-01 → 02)
- Policy verified (API key is the sanctioned path; Max plan $100/month API credits). Benchmarks in docs/ARCHITECTURE.md.
- Phases 1–5 built; then a day of fixes driven by the user's screenshots: VS Code terminal selection (Claude Code mouse capture, OSC 52), panel placement/size, screenshot card, copyable text, validator false positives, Chrome extension, and finally the scope reset.

## Open questions
- None from the user. Do not reopen Safari inline translation, hotkeys or fallbacks unless asked.
