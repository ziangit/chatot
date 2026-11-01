# Session handoff

**Current phase:** Phases 1–5 implemented and installed (v0.1.0); awaiting the user's hands-on check of the two permission-gated paths.
**Next concrete step:** User reloads VS Code/Cursor window and right-clicks a terminal selection → 'Translate with Chatot'; tries ⌥⌘T in Terminal/VS Code/Chrome (grants Accessibility when prompted) and ⌥⌘R (grants Screen Recording), reports anything off. Then Phase 6 polish: "Ask about this" action, per-app overrides, language auto-detect, launch at login, hotkey customization, glossary auto-consistency across chunks.

## Done so far (2026-11-01)
- Git repo initialized on `main`, remote `origin` = https://github.com/ziangit/chatot (remote is empty, nothing pushed).
- Policy verified: subscription OAuth may only be used by the unmodified CLIs; API key is the sanctioned path. Max plan includes $100/month API credits (claim via claude.ai Settings > Billing). User's Console org already holds ~$295 credits.
- Benchmarked Claude CLI (Haiku, Fable), Codex CLI (gpt-6-astra, gpt-6-luna, gpt-reserve, gpt-6.1-sol), local Qwen3 8B/4B via Ollama, Apple Vision OCR, and model vision. Numbers in docs/ARCHITECTURE.md.
- Translation prompt shortened and tested (prompts/translate.md); screenshot prompt tested (prompts/screenshot.md).
- `.gitignore` protects `.env`; `.env.example` documents variables. `ANTHROPIC_API_KEY` is set in `.env`.
- API benchmark done 2026-11-01: first text 0.5 s, 855 words in 11.7 s single / 4.2 s chunked, screenshot 4.3 s, ~$0.0015 per long translation. See docs/ARCHITECTURE.md.
- Ollama 0.40 installed via brew with qwen3:8b and qwen3:4b pulled (optional local tier; can be removed).

## Verified automatically (2026-11-01)
- `swift build` clean; `swift run chatot-tests` 32 checks, 0 failures.
- CLI end-to-end through the API: 855 words in 2.8 s over 9 segments, table passed through; screenshot path works.
- Installed app: launches as menubar-only, hotkeys registered, Service registered (`pbs -dump_pboard`), `NSPerformService` invocation translated in 1.5 s, panel rendered correctly (self-render hook).
- 2026-11-01 later: app moved to /Applications with icon; `chatot://` URL scheme verified; VS Code extension packaged and installed into VS Code and Cursor (needs window reload).
- NOT yet exercised by a human: ⌥⌘T selection reading (needs Accessibility grant), ⌥⌘R region capture (needs Screen Recording grant), the Services menu item clicked from a real right-click, Settings window, Pin/Copy buttons.

## Phase plan
1. DONE Scaffold: Swift package, menubar app, settings, `.env`/keychain loading.
2. DONE Providers: Claude Messages API (primary), Codex CLI (fallback), Claude CLI (fallback), Ollama (optional). Chunker + validator + glossary. Benchmark warm vs cold.
3. DONE (untested by human) Text triggers: macOS Services menu item; global hotkey with Accessibility selection read and clipboard fallback. Verify in Terminal.app, iTerm2, VS Code, Chrome.
4. DONE Floating non-activating panel with streaming, Copy, Pin.
5. DONE (untested by human) Screen-region capture → image to Haiku; Vision OCR concurrently for bounding boxes/overlay.
6. Polish: per-app overrides, language auto-detect, launch at login; optional browser extension for inline page translation.

## Open questions
- Default target language assumed Simplified Chinese (user's prompt is EN→ZH). Confirm.
- Chrome-only vs Safari extension later (Safari needs Xcode wrapper).
- Code signing: ad-hoc builds re-prompt Accessibility after each rebuild; decide on free Apple ID dev cert vs installing Xcode.
