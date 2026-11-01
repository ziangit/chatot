# Session handoff

**Current phase:** Phase 0 complete — planning done, docs scaffolded, API benchmarked (no app code yet)
**Next concrete step:** Phase 1 — create the Swift package (`Package.swift`, menubar app target, settings, `.env`/keychain loading), then Phase 2 providers starting with the Claude Messages API client (streaming, thinking disabled, effort low, cached system prompt).

## Done so far (2026-11-01)
- Git repo initialized on `main`, remote `origin` = https://github.com/ziangit/chatot (remote is empty, nothing pushed).
- Policy verified: subscription OAuth may only be used by the unmodified CLIs; API key is the sanctioned path. Max plan includes $100/month API credits (claim via claude.ai Settings > Billing). User's Console org already holds ~$295 credits.
- Benchmarked Claude CLI (Haiku, Fable), Codex CLI (gpt-6-astra, gpt-6-luna, gpt-reserve, gpt-6.1-sol), local Qwen3 8B/4B via Ollama, Apple Vision OCR, and model vision. Numbers in docs/ARCHITECTURE.md.
- Translation prompt shortened and tested (prompts/translate.md); screenshot prompt tested (prompts/screenshot.md).
- `.gitignore` protects `.env`; `.env.example` documents variables. `ANTHROPIC_API_KEY` is set in `.env`.
- API benchmark done 2026-11-01: first text 0.5 s, 855 words in 11.7 s single / 4.2 s chunked, screenshot 4.3 s, ~$0.0015 per long translation. See docs/ARCHITECTURE.md.
- Ollama 0.40 installed via brew with qwen3:8b and qwen3:4b pulled (optional local tier; can be removed).

## Phase plan
1. Scaffold: Swift package, menubar app, settings, `.env`/keychain loading.
2. Providers: Claude Messages API (primary), Codex CLI (fallback), Claude CLI (fallback), Ollama (optional). Chunker + validator + glossary. Benchmark warm vs cold.
3. Text triggers: macOS Services menu item; global hotkey with Accessibility selection read and clipboard fallback. Verify in Terminal.app, iTerm2, VS Code, Chrome.
4. Floating non-activating panel with streaming, Copy, Pin.
5. Screen-region capture → image to Haiku; Vision OCR concurrently for bounding boxes/overlay.
6. Polish: per-app overrides, language auto-detect, launch at login; optional browser extension for inline page translation.

## Open questions
- Default target language assumed Simplified Chinese (user's prompt is EN→ZH). Confirm.
- Chrome-only vs Safari extension later (Safari needs Xcode wrapper).
- Code signing: ad-hoc builds re-prompt Accessibility after each rebuild; decide on free Apple ID dev cert vs installing Xcode.
