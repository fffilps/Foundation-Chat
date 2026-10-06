# fmx — Foundation Models CLI for macOS 26+

Apple ships the system **`fm`** CLI with **macOS 27**.  
**`fmx`** brings the same core workflow to **macOS 26 (Tahoe)** and later, so you can support earlier Macs and teammates who aren’t on 27 yet.

It talks to the on-device Apple Foundation Model through the official **`FoundationModels`** Swift framework (same engine as Foundation Chat and as system `fm` on 27). No API key. No cloud.

> This is **not** Apple’s binary. On macOS 27, `/usr/bin/fm` remains the first-party CLI. Use `fmx` when you need **macOS 26 compatibility** or a portable install from this repo.

## Requirements

- macOS 26.0+
- Apple Silicon with Apple Intelligence enabled
- Xcode 26+ / Swift 6 toolchain (to build)

## Install

```bash
cd fmx
swift build -c release
cp .build/release/fmx /usr/local/bin/fmx   # or any directory on your PATH
```

Or run without installing:

```bash
swift run fmx available
swift run fmx respond "What is Swift?"
swift run fmx chat
```

## Commands (fm-shaped)

| Command | Like system `fm` | Purpose |
| --- | --- | --- |
| `fmx available` | `fm available` | Check if the on-device model is ready |
| `fmx respond` | `fm respond` | One-shot generation (stdin OK, streaming default) |
| `fmx chat` | `fm chat` | Interactive multi-turn chat |
| `fmx count-tokens` | `fm count-tokens` | Token counts for prompts / instructions |
| `fmx schema object` | `fm schema object` | Build a schema JSON for structured output |

### Examples

```bash
fmx available
fmx respond "Summarize concurrency in Swift"
echo "Rewrite this politely: ship it yesterday" | fmx respond -i "You are a careful editor"
fmx respond --no-stream --greedy "List 3 sorting algorithms"
fmx chat -i "You are a terse shell expert"

fmx schema object --name Person --string name --int age -o person.json
fmx respond --schema person.json "Invent a fictional engineer"

fmx count-tokens -i "Be brief" "Explain ARC"
```

### Chat slash commands

```
/help     /clear     /system <text>     /model     /exit
```

## How this relates to other projects

| Thing | What it is |
| --- | --- |
| `/usr/bin/fm` | Apple’s first-party CLI (macOS **27+**) |
| `fmx` (this folder) | Native Swift CLI for **macOS 26+**, fm-compatible core commands |
| [brianwestphal/apple-fm](https://github.com/brianwestphal/apple-fm) | Third-party Node + Swift helper (`probe` / `generate` / `chat`) |
| [manjunathshiva/fmx](https://github.com/manjunathshiva/fmx) | Third-party Python CLI on `apple-fm-sdk` |
| Foundation Chat (this repo’s Mac app) | GUI for the same on-device model |

## Notes

- Only the **system** (on-device) model is supported. Private Cloud Compute is not exposed here.
- Structured output uses `DynamicGenerationSchema` from schemas written by `fmx schema object`.
- Token counting uses the real tokenizer on macOS 26.4+; earlier 26.x falls back to a rough estimate.
