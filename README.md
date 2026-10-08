# Foundation Chat

A native macOS chat app for **local models**, starting with Apple’s on-device **Foundation Models** — the same engine behind the `fm` CLI, with a real Mac GUI.

## Download

**[Latest release (1.0.1)](https://github.com/fffilps/Foundation-Chat/releases/latest)** — grab the macOS `.zip`, unzip, open `FoundationChat.app`.

Requirements: macOS 26+, Apple Silicon, Apple Intelligence enabled, on-device model downloaded.

If macOS blocks the app (before notarization or on first open): right-click the app → **Open** → **Open**.

## Features

- Streaming on-device chat (same `SystemLanguageModel` as `fm`)
- **Markdown replies** — bold, lists, headings, and fenced code blocks render in the chat
- **Context meter** with live token counts (`fm count-tokens` equivalent)
- Instructions + presets (coding, writing, concise, teacher, tagger)
- Generation options: temperature, max tokens, greedy sampling, use case, guardrails
- Help guide with context / CLI / privacy topics
- Export / copy transcripts, rename chats, prompt starters
- Settings window for status + machine profile + options

## Requirements

- macOS 26+ (you’re on macOS 27)
- Apple Silicon Mac with Apple Intelligence support
- Xcode 26+
- Apple Intelligence enabled in **System Settings → Apple Intelligence & Siri**
- On-device model finished downloading (`fm available` should succeed)

## Open & run

```bash
open "FoundationChat.xcodeproj"
```

In Xcode: select the **FoundationChat** scheme → **My Mac** → press **Run** (⌘R).

Or build from the terminal:

```bash
xcodebuild -scheme FoundationChat -configuration Debug -derivedDataPath build
open "build/Build/Products/Debug/FoundationChat.app"
```

## Local model catalog

| Model | Provider | Phase 1 |
|-------|----------|---------|
| Apple Foundation Model — General | Apple Foundation | Live |
| Apple Foundation Model — Content Tagging | Apple Foundation | Live |
| Ollama | Ollama | Stub (coming soon) |
| Hugging Face | Hugging Face | Stub (coming soon) |
| Unsloth export | Unsloth | Stub (coming soon) |

Fit badges use `FoundationChat/Resources/ModelRequirements.json`. After testing on real Macs, tighten the numbers there—no code changes required for threshold tweaks.

## If the model isn’t ready

Your machine currently reports `modelNotReady` from `fm available`. That means the on-device model is still downloading or preparing. Keep the Mac awake, leave Apple Intelligence on, then tap **Check Again** in the app (or run `fm available`).

## Notes

- All inference stays local (on-device Apple FM today; future providers stay local too).
- Chats are saved locally under Application Support (`FoundationChat/conversations.json`).
- Future model caches use Application Support (`FoundationChat/Models`).
- This uses the official `FoundationModels` Swift framework, not a wrapper around the CLI.
