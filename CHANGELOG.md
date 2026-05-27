## 0.1.11 (2026-05-27)

### Features

- upgrade ElevenLabs to Scribe v2 realtime protocol
- update default models to match Rust v0.2.12
- wire hotkey, opacity, and theme from AppConfig
- add PromptStore and PromptSet for runtime-editable prompts
- hot-swap LLM, output mode, and dictionary on config change
- paginate, debounce search, and use relative timestamps
- open Settings window on first launch
- redesign UI with sidebar nav + Prompts editor
- add Apple STT model download UI with progress
- integrate Sparkle for in-app auto-update
- DMG packaging, signing, notarization, Sparkle, Homebrew
- add iOS and iPadOS support
- add native WhisperKit STT provider
- polish WhisperKit model management UI
- instrument WhisperKit realtime transcription
- add WhisperKit realtime tuning controls
- log WhisperKit diagnostics
- harden WhisperKit stop cancellation
- add WhisperKit diagnostics panel

### Fixes

- unblock Swift build and release workflow
- drop deinit observer cleanup that violated strict concurrency

## 0.1.10 (2026-02-27)

### Features

- enforce Traditional Chinese and preserve original language in prompts
- add custom OpenAI-compatible STT endpoint support
- add full ElevenLabs language selector with ISO 639-3 mapping

## 0.1.9 (2026-02-15)

### Features

- add HTTP API LLM processors with model override and custom endpoints
- add rich personal dictionary with entries, aliases, and search

## 0.1.8 (2026-02-15)

### Features

- add multilingual STT language config for cloud providers

### Fixes

- resolve pipeline deadlock ("stuck at Transcribing")

## 0.1.7 (2026-02-15)

### Fixes

- auto-download on-device speech model when not installed

## 0.1.6 (2026-02-14)

### Fixes

- fall back to same-language locale when system locale unsupported by Apple Speech

## 0.1.5 (2026-02-14)

### Fixes

- improve STT unsupported locale error with actionable details

## 0.1.4 (2026-02-14)

### Fixes

- strip script subtags from auto-detected locale for SpeechTranscriber

## 0.1.3 (2026-02-14)

### Features

- implement Phase 1 - audio capture, Apple STT, and minimal UI
- implement Phase 3 - macOS chrome, multi-provider STT/LLM, and tests
- implement Phase 4 - settings, history, and personal dictionary
- implement Phase 5 - permissions, error handling, and tests

### Fixes

- use commit message to route release workflow jobs
- prevent false positive trigger and knope binary failure
- correct release commit prefix to 'chore: prepare release'

## 0.1.2 (2026-02-14)

### Features

- implement Phase 1 - audio capture, Apple STT, and minimal UI
- implement Phase 3 - macOS chrome, multi-provider STT/LLM, and tests
- implement Phase 4 - settings, history, and personal dictionary
- implement Phase 5 - permissions, error handling, and tests

### Fixes

- use commit message to route release workflow jobs
- prevent false positive trigger and knope binary failure

## 0.1.1 (2026-02-14)

### Features

- implement Phase 1 - audio capture, Apple STT, and minimal UI
- implement Phase 3 - macOS chrome, multi-provider STT/LLM, and tests
- implement Phase 4 - settings, history, and personal dictionary
- implement Phase 5 - permissions, error handling, and tests
