# chatot — product

## What it is
A macOS menubar app that translates whatever you point at, anywhere on screen: selected text in any app (browser, terminal, editor, PDF viewer) or a region of the screen containing text or an image. The translation streams into a floating panel next to the cursor. It is built for one user who already pays for Claude Max and ChatGPT and wants fast translation without a separate translation subscription. Immersive Translate is the reference experience, but system-wide instead of browser-only.

## Features
- Right-click → Services → "Translate with Chatot" on selected text or an image (works in Terminal.app, iTerm2, Safari, Chrome, Finder, Preview, most native apps).
- Global hotkey translates the current selection in any app, including Electron apps where Services don't appear (Accessibility API, clipboard fallback).
- Screen-region hotkey: drag a rectangle, text in it is translated (works on images, video frames, canvas apps, remote desktops).
- macOS screenshots: after ⇧⌘3/4/5 (file saved) or "Copy Image" in the screenshot preview, a floating "译 Translate screenshot" button appears bottom-right for 15 s; click to translate. Also: drag the screenshot thumbnail onto the menubar icon, or menubar → Translate Last Screenshot.
- Floating, non-activating panel with streaming output, Copy, Pin.
- Progressive rendering: long text is split into paragraphs, translated in parallel, shown as each lands. First text in ~1-2 s.
- Providers: Claude Haiku 5.5 via Messages API (primary), Codex CLI with ChatGPT login (fallback), Claude CLI (fallback), local Ollama (optional offline tier).
- Output validation: every chunk checked for Chinese-character ratio and plausible length; retried, then failed over, never shown wrong silently.
- Glossary passed with each chunk for consistent terminology across chunks.
- Default direction English → Simplified Chinese; target language configurable.
- Tables and code blocks pass through untranslated by default; prose around them is translated.

## Non-goals (explicitly out of scope for now)
- Full-page inline bilingual rendering of web pages (optional browser extension later; right-click Services already works in browsers).
- Replacing text inside images in place (re-rendered image). Phase 1 shows translation beside/over the image.
- Multi-user or distribution: single-user personal tool. If ever distributed, each user must bring their own API key / CLI login.
- Any use of web-session scraping or OAuth-token extraction for Claude or ChatGPT.
- Video subtitle translation.
- Windows / Linux.
