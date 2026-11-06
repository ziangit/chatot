# Session handoff

**Current phase:** v0.3 (2026-11-02) — pixel Chatot icon, provider options (Claude default / ChatGPT / DeepSeek), English + Chinese UI. Built, installed, relaunched, pushed. GitHub release v0.3.0 (app zip, .vsix, Chrome extension zip) and bilingual READMEs for the Xiaohongshu post.
**Next concrete step:** User posts on Xiaohongshu / V2EX / 即刻 linking the release. Before that, the user reloads the Chrome extension once (chrome://extensions ▸ ↻, manifest changed for i18n) and checks the new icon and Settings ▸ Language. Then exercises the four paths and reports: (1) right-click in the Claude Code terminal → Translate with Chatot; (2) right-click in Chrome → Translate with Chatot / Translate image with Chatot; (3) right-click in a native app → Services ▸ Translate with Chatot; (4) take a screenshot → card → click. Then stop adding features unless asked.

## UX rules from the user (non-negotiable)
- "I just want select, right click, and translate." No modifier keys, no "press ⌘C first", no hints telling the user to do something different.
- 2026-11-02: "how many functions are not asked by me? Just keep my intended function." Do not add features, menu items, hotkeys, fallbacks or prompts that were not requested. API keys only (Claude by default; ChatGPT/DeepSeek options were requested 2026-11-02).

## What exists now
- Chatot.app (menubar: pixel Chatot icon; Pause / Settings / Quit). Settings: Language (System/English/中文), target language, Provider picker (Claude / ChatGPT / DeepSeek) with a model dropdown + key per provider, target-language dropdown, screenshot toggle. All UI strings via `L()` in `L10n.swift`. Triggers: Services item (text + image), `chatot://translate?text=` and `chatot://image?url=` URL scheme, screenshot card (clipboard image or new file in the screenshot folder).
- Panel: placed off the selection (mouse band), grows with content, native text view (select, ⌘C, Original toggle, Copy, Close), screenshot output shows translations only.
- VS Code/Cursor extension 0.2.1 (`vscode-extension/`): terminal/editor right-click items only, localized (nls), installed in both.
- Chrome extension 0.2.0 (`chrome-extension/`, loaded unpacked by the user, ID mhkpkmkbjfdikhgjlnkfakkdhoennoai, now with `_locales` en/zh_CN and the pixel icon) + native-messaging host registered for Chrome/Chromium/Brave/Edge/Arc. Needs one reload by the user.
- Core: Chunker, Validator (lenient for short labels/names; CJK→English auto-detect), Glossary, ClaudeAPIProvider (default) + OpenAICompatibleProvider (ChatGPT, DeepSeek text-only); one provider active at a time. Tests: `swift run chatot-tests` (64 checks). 2026-11-06: preamble-leak fix (prompt rule + `Validator.stripPreamble` + stream hold-back + reject/retry with nudge; see ARCHITECTURE "Preamble leak"); `Config.description` redacts keys (issue #1, filed by an automated scanner account; verify such reports before acting).

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
- Never close, comment on or change a public GitHub issue (including "fixes #N" in commit messages) unless the user asks; "check this" means verify and report only.

## Releasing
`scripts/release.sh <version>` builds the app, re-signs a copy ad hoc, zips it with the .vsix and the Chrome extension (plus install.sh), tags and creates the GitHub release. Bump `CFBundleShortVersionString` in scripts/Info.plist first. Release apps are not notarized; the README tells users to clear quarantine.
