# Prompt-Preflight

Prompt-Preflight is a macOS menu bar app for compressing and restructuring prompt text before sending it to an LLM.

It provides a two-panel editor (`Input Text` and `Response Text`), token preflight checks, provider/model switching, local history, and keychain-backed credential storage.

## Features

- Menu bar app (`LSUIElement`) with a popover-style main window
- Global shortcut to open the window: `Cmd + Option + P`
- Editable input and response text areas
- Provider support: OpenAI, Gemini, Anthropic, Ollama
- Per-provider model selection and custom system prompt override
- Token preflight estimator with model-aware limits
- Request cancel support and transient HTTP retry handling
- Optional history persistence (SwiftData) with retention policy
- Private mode to skip history writes
- API keys/tokens stored in macOS Keychain

## Requirements

- macOS 14+
- Xcode 16+ or Swift 6.2 toolchain

## Quick Start

1. Build and run:

```bash
swift run PromptPreflight
```

2. Open `Settings` in the app and save the API key/token for the provider you want to use.

3. Set provider + model, paste input text, then click `Send`.

## Provider Setup

Credentials are stored in Keychain under service name `PromptPreflight`.

- OpenAI: API key
- Gemini: API key
- Anthropic: API key
- Ollama: optional bearer token

For Ollama, also configure the base URL in Settings (default: `http://localhost:11434`).

## Development

Build:

```bash
swift build
```

Test:

```bash
swift test
```

If you have a running app process and want a clean rebuild, use:

```bash
./scripts/swift_build_with_kill.sh
```

## Packaging (DMG)

Create a release app bundle and DMG:

```bash
./scripts/build_dmg.sh
```

Optional environment variables:

- `VERSION` (default `1.0.0`)
- `BUNDLE_ID` (default `com.promptpreflight.app`)
- `CODESIGN_IDENTITY` (if set, the app bundle is codesigned before DMG creation)

Output path:

- `.build/dmg/Prompt-Preflight.dmg`

## Data and Privacy

- Chat history is stored at `~/Library/Application Support/PromptPreflight/history.store` when `Save History` is enabled.
- `Private Mode` disables history writes for the current run.
- API keys are not written to project files; they are stored in macOS Keychain.

## Project Structure

- `Sources/PromptPreflight/PromptPreflightApp.swift`: app entry, model container, menu bar scene
- `Sources/PromptPreflight/Views/`: main UI, settings, and history screens
- `Sources/PromptPreflight/ViewModels/MainViewModel.swift`: request flow, preflight, persistence hooks
- `Sources/PromptPreflight/Networking/LLMClient.swift`: provider-specific HTTP clients
- `Sources/PromptPreflight/Services/`: gateway, keychain, token estimator, hotkey/window services
- `Tests/PromptPreflightTests/`: unit tests for settings, view model, retries, token estimator, rich text, keychain

## Notes

Default system prompt:

```text
Lossless compression task:

preserve 100% meaning
remove redundancy only
structure for machine parsing
output markdown only
no interpretation or omission
```

## Community

- Contributing guide: [CONTRIBUTING.md](CONTRIBUTING.md)
- Code of conduct: [CODE_OF_CONDUCT.md](CODE_OF_CONDUCT.md)
- Security policy: [SECURITY.md](SECURITY.md)

## License

MIT. See [LICENSE](LICENSE).
