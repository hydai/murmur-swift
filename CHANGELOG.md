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
