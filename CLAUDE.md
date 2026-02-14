# Murmur (Swift) - Project Instructions

## Overview

Native Swift/SwiftUI rebuild of Murmur. Privacy-first BYOK voice typing app. Targets macOS 26+ / iOS 26+. Zero external dependencies.

## Build & Test

```bash
# Build Swift package
cd MurmurKit && swift build

# Run all tests (18 tests, 5 suites)
cd MurmurKit && swift test

# Build full app via xcodebuild
xcodebuild -workspace Murmur.xcworkspace -scheme Murmur -configuration Release build

# Run tests via xcodebuild
xcodebuild -workspace Murmur.xcworkspace -scheme Murmur -destination 'platform=macOS' test
```

## Project Structure

- `MurmurKit/` — Swift Package (zero deps), all domain logic and implementations
  - `Sources/Audio/` — AudioCaptureService, AudioResampler, VadProcessor
  - `Sources/Config/` — ConfigManager (JSON), HistoryStore
  - `Sources/Domain/` — Protocols (SttProvider, LlmProcessor, OutputSink), domain types (AppConfig, AudioChunk, TranscriptionEvent, ProcessingTask, etc.)
  - `Sources/LLM/` — AppleLlmProcessor, GeminiProcessor, CopilotProcessor, CliExecutor, PromptManager
  - `Sources/Output/` — ClipboardOutput, KeyboardOutput, CombinedOutput
  - `Sources/Pipeline/` — PipelineOrchestrator, VoiceCommandDetector
  - `Sources/STT/` — AppleSttProvider, ElevenLabsProvider, OpenAIProvider, GroqProvider, AudioChunker
  - `Tests/` — AudioTests, ConfigTests, DomainTests (Swift Testing framework: `@Suite`, `@Test`)
- `MurmurApp/` — Xcode project (imports MurmurKit)
  - `Shared/` — MurmurApp.swift, ViewModels/, Views/
  - `macOS/` — OverlayWindow, SystemTrayManager, GlobalHotkeyManager, PermissionsManager, SoundManager, OverlayView
  - `Resources/` — Info.plist, entitlements
- `prompts/` — LLM prompt templates (post_process, shorten, translate, change_tone, generate_reply)

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

5 suites, 18 tests (Swift Testing framework):
- `AudioChunkerTests` — WAV encoding, RIFF header validation
- `ConfigManagerTests` — Default config, save/load round-trip, update persistence
- `HistoryStoreTests` — CRUD, search, max entries cap, persistence
- `AppConfigTests` — Default values, JSON round-trip
- `VoiceCommandDetectorTests` — Command detection for shorten/tone/translate/reply
