# chatot

System-wide macOS translator: right-click, hotkey, or screen-region capture on text or images in any app (including the terminal), and the translation appears in a floating panel. Fast, and runs on the user's existing Claude and ChatGPT subscriptions.

@docs/PRODUCT.md
@session-handoff.md

## Conventions
- Native Swift (AppKit + SwiftUI), Swift Package Manager, no Xcode project unless signing forces it.
- Small, shippable phases; each phase ends with a working app, not a half-built one.
- Every provider call goes through the `Provider` protocol; UI never talks to a model directly.
- Every translation chunk is validated before display (CJK ratio, length plausibility) and retried on failure.
- Benchmarks are recorded in docs/ARCHITECTURE.md with the date; decisions cite numbers, not vibes.
- Tests: `swift run chatot-tests` (plain executable harness; Command Line Tools ship no XCTest). End-to-end: `swift run chatot-cli translate "text"`.
- Use the `claude-api` skill when writing or changing Anthropic API code.

## Hard constraints (never violate)
- Never call claude.ai or chatgpt.com web endpoints, scrape web sessions, or extract OAuth tokens. Claude = Messages API with the key in `.env` (fallback: unmodified `claude` CLI). ChatGPT = unmodified `codex` CLI with ChatGPT login.
- Never commit `.env` or any secret. `ANTHROPIC_API_KEY` is read from `.env` or the keychain only.
- Never use the Claude Code `--bare` flag (it disables subscription OAuth).
- Default Claude model is Haiku 5.5; never silently switch to a costlier model.
- Translation prompts must never answer or continue the source text; see prompts/.
- Do not translate tables or code blocks by default; pass them through.

## Where to look
- Technical reference & gotchas: docs/ARCHITECTURE.md (read on demand)
- Prompts: Sources/ChatotCore/Prompts/translate.md (text), screenshot.md (images)
