# Foundation Chat

A native macOS chat app for Apple’s on-device **Foundation Models** — the same engine behind Apple’s `fm` CLI (macOS 27) and this repo’s **`fmx`** CLI (macOS 26+).

## Features

- Streaming on-device chat (same `SystemLanguageModel` as `fm` / `fmx`)
- **Context meter** with live token counts (`fm count-tokens` / `fmx count-tokens` equivalent)
- Instructions + presets (coding, writing, concise, teacher, tagger)
- Generation options: temperature, max tokens, greedy sampling, use case, guardrails
- Help guide with context / CLI / privacy topics
- Export / copy transcripts, rename chats, prompt starters
- Settings window for status + options

## CLI for macOS 26 (`fmx`)

Apple’s first-party `fm` ships with **macOS 27**. For **macOS 26** (and portable installs), this repo includes **`fmx`** — an fm-shaped Swift CLI:

```bash
cd fmx
swift build -c release
./.build/release/fmx available
./.build/release/fmx respond "Hello"
./.build/release/fmx chat
```

See [fmx/README.md](fmx/README.md).

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

## If the model isn’t ready

Your machine currently reports `modelNotReady` from `fm available`. That means the on-device model is still downloading or preparing. Keep the Mac awake, leave Apple Intelligence on, then tap **Check Again** in the app (or run `fm available`).

## Notes

- All inference stays on device.
- Chats are saved locally under Application Support (`FoundationChat/conversations.json`).
- This uses the official `FoundationModels` Swift framework, not a wrapper around the CLI.
