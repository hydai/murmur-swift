# Murmur (Swift) - Project Instructions

## Overview

Native Swift/SwiftUI rebuild of Murmur. Privacy-first BYOK voice typing app. Targets macOS 26+ / iOS 26+. MurmurKit depends on Argmax WhisperKit for native on-device Whisper STT.

## Build & Test

```bash
# Build Swift package
cd MurmurKit && swift build

# Run all tests (137 tests, 23 suites)
cd MurmurKit && swift test

# Build full app via xcodebuild
xcodebuild -workspace Murmur.xcworkspace -scheme Murmur -configuration Release build

# Run tests via xcodebuild
xcodebuild -workspace Murmur.xcworkspace -scheme Murmur -destination 'platform=macOS' test
```

## Project Structure

- `MurmurKit/` — Swift Package, all domain logic and implementations
  - `Sources/Audio/` — AudioCaptureService, AudioResampler, VadProcessor
  - `Sources/Config/` — ConfigManager (JSON), HistoryStore, RelativeTimestampFormatter
  - `Sources/Domain/` — Protocols (SttProvider, LlmProcessor, OutputSink), AppConfig, HotkeySpec, ProviderDefaults, Notifications, AudioChunk, TranscriptionEvent, ProcessingTask, etc.
  - `Sources/LLM/` — AppleLlmProcessor, OpenAILlmProcessor, ClaudeLlmProcessor, GeminiApiProcessor, CustomOpenAIProcessor, GeminiProcessor, CopilotProcessor, HttpLlmClient, CliExecutor, PromptName, PromptSet, PromptStore, PromptManager, DefaultPromptTemplates
  - `Sources/Output/` — ClipboardOutput, KeyboardOutput, CombinedOutput
  - `Sources/Pipeline/` — PipelineOrchestrator, TranscriptionAccumulator, VoiceCommandDetector
  - `Sources/STT/` — AppleSttProvider, WhisperKitProvider, WhisperKitRuntimeStore, WhisperKitModelManager, AppleSttModelManager, ElevenLabsProvider, OpenAIProvider, GroqProvider, CustomSttProvider, AudioChunker, ElevenLabsLanguages
  - `Tests/` — AudioTests, ConfigTests, DomainTests, LLMTests, OutputTests, PipelineTests, STTTests (Swift Testing framework: `@Suite`, `@Test`)
- `MurmurApp/` — Xcode project (depends on MurmurKit + Sparkle)
  - `Shared/MurmurApp.swift` — @main + AppDelegate (tray, hotkey, overlay, updates, config observer)
  - `Shared/ViewModels/` — Pipeline, Settings, History view models (@Observable @MainActor)
  - `Shared/Views/` — TranscriptionView, HistoryView, WaveformIndicator
  - `Shared/Views/Settings/` — NavigationSplitView shell + 8 section views (General/STT/LLM/Output/Hotkey/Dictionary/Prompts/About), DesignTokens, SettingsPrimitives, HotkeyCaptureField, AppleSttModelStatusView, WhisperKitModelStatusView
  - `macOS/` — OverlayWindow, SystemTrayManager, GlobalHotkeyManager, PermissionsManager, SoundManager, ThemeApplier, UpdateManager (Sparkle wrapper), OverlayView
  - `Resources/` — Info.plist (SUFeedURL, SUEnableAutomaticChecks, SUPublicEDKey, LSUIElement, mic/accessibility/speech usage descriptions), entitlements
- `prompts/` — LLM prompt templates (post_process, shorten, translate, change_tone, generate_reply)
- `scripts/build-dmg.sh` — wraps create-dmg for the release workflow
- `.githooks/pre-commit` — lineguard + swift build + swift test (activate via `git config core.hooksPath .githooks`)

## Key Conventions

### Swift 6.2 Strict Concurrency
- Use actors for mutable shared state
- Use `AsyncStream` for event streams (transcription events, pipeline events, audio levels)
- All public types must be `Sendable`
- Use `nonisolated` for methods that emit to `AsyncStream.Continuation` (continuations are thread-safe)
- Local value captures when crossing actor isolation boundaries — closures crossing MainActor→actor boundary must not capture `self`

### SwiftUI
- Use `@Observable` macro (not `ObservableObject` / `@Published`)
- ViewModels are `@Observable @MainActor` classes

### Configuration
- JSON config with `snake_case` key encoding (`JSONEncoder.KeyEncodingStrategy.convertToSnakeCase`)
- Config path: `~/Library/Application Support/com.hydai.Murmur/config.json`

### Framework Imports
- Use `@preconcurrency import` for frameworks with Sendable conformance issues (e.g., `@preconcurrency import Speech`)

## Common Pitfalls

- `.macOS(.v26)` / `.iOS(.v26)` platform requirements need `swift-tools-version: 6.2` in Package.swift
- `SpeechTranscriber` results use `.text` (returns `AttributedString`), NOT `.transcription.formattedString`
- `weak` cannot be applied to struct types — `AsyncStream.Continuation` is a struct, not a class
- Closures crossing `@MainActor` → actor isolation boundary must capture values (not `self`) to avoid data races
- Audio capture uses `AVAudioEngine` with tap on input node — must handle sample rate conversion (device rate → 16kHz for STT APIs)
- WAV encoding for cloud STT APIs: RIFF header + PCM data, little-endian Int16 samples

## Test Structure

23 suites, 137 tests (Swift Testing framework):
- `AudioChunkerTests` — WAV encoding, RIFF header validation
- `ConfigManagerTests` — Default config, save/load round-trip, update persistence
- `HistoryStoreTests` — CRUD, search, max entries cap, persistence
- `RelativeTimestampFormatterTests` — Today/Yesterday/Nd-ago/absolute formatting
- `AppConfigTests` — Default values, JSON round-trip, backward compatibility, HttpSttConfig
- `PersonalDictionaryTests` — Entry CRUD, JSON round-trip, search by term/alias/description
- `VoiceCommandDetectorTests` — Command detection for shorten/tone/translate/reply
- `HotkeySpecTests` — modifier aliases, key code table, parse failures
- `ProviderDefaultsTests` — locks default model strings against the Rust upstream
- `HttpLlmTests` — OpenAI/Claude/Gemini response parsing, auth strategies, URL building
- `PromptManagerTests` — Chinese Language Rule, override behaviour, placeholder substitution
- `PromptStoreTests` — disk persistence round-trips, reset semantics
- `CustomSttProviderTests` — Construction with default/custom/nil-key parameters
- `WhisperKitProviderTests` — Construction, runtime key/status behaviour, realtime options, realtime segment state, and PCM normalization for native WhisperKit STT
- `WhisperKitModelManagerTests` — Model catalog normalization, local folder validation, and cache size display
- `WhisperKitCacheDeletionIntegrationTests` — Opt-in real tiny-model download/cache/delete verification under a temporary home
- `WhisperKitTranscriptionIntegrationTests` — Opt-in real tiny-model provider transcription with realtime partial and final transcript checks
- `ElevenLabsLanguagesTests` — ISO 639-1→639-3 mapping, unique IDs, language count
- `ElevenLabsProtocolTests` — URL builder, PCM-to-base64, response parsing for Scribe v2
- `TranscriptionAccumulatorTests` — trailing-partial fallback (Apple STT case)
- `CombinedOutput routing` — clipboard / keyboard / both wiring (serialized to share pasteboard)
