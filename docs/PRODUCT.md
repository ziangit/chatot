# chatot — product

## What it is
A macOS menubar app that translates whatever you point at, anywhere on screen: selected text in any app (browser, terminal, editor, PDF viewer) or a region of the screen containing text or an image. The translation streams into a floating panel next to the cursor. It is built for one user who already pays for Claude Max and ChatGPT and wants fast translation without a separate translation subscription. Immersive Translate is the reference experience, but system-wide instead of browser-only.

## Features (exactly what the user asked for; scope reset 2026-11-02)
- Right-click selected text or an image → "Translate with Chatot". Native apps via Services ▸; VS Code/Cursor terminal and editor via a tiny extension (top-level item); Chrome via a tiny extension (top-level items for text and images).
- macOS screenshots: after a screenshot is saved or "Copy Image" is clicked, a small card with the thumbnail and "译 Translate this screenshot" appears next to the mouse for 10 s (×, click elsewhere, or Settings to turn off).
- Floating panel placed off the selected text, growing to fit the translation as it streams; text is selectable and ⌘C works; Original toggle; Copy; Close.
- Provider: Claude Haiku 5.5 via the Messages API, key from `.env` or keychain. Nothing else.
- Progressive rendering: long text is split into paragraphs, translated in parallel, shown as each lands.
- Output validation: chunks checked for plausibility; retried; never shown wrong silently.
- Glossary passed with each chunk; tables and code blocks pass through untranslated.
- Default direction English → Simplified Chinese (configurable); text already in Chinese is translated to English.
- Menubar: Pause/Resume, Settings, Quit.

## Non-goals (explicitly out of scope for now)
- Hotkeys, screen-region capture, floating selection buttons, clipboard/last-screenshot menu items, Pin, CLI/Ollama fallbacks, Accessibility prompts: built, then removed 2026-11-02 because the user did not ask for them.
- Full-page inline bilingual rendering of web pages (optional browser extension later; right-click Services already works in browsers).
- Replacing text inside images in place (re-rendered image). Phase 1 shows translation beside/over the image.
- Multi-user or distribution: single-user personal tool. If ever distributed, each user must bring their own API key / CLI login.
- Any use of web-session scraping or OAuth-token extraction for Claude or ChatGPT.
- Video subtitle translation.
- Windows / Linux.
