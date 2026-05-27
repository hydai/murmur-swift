# Native WhisperKit Provider Specification

## Goal

Add Argmax WhisperKit as a first-class native speech-to-text provider in
Murmur. The provider must run in-process through the Swift package, not through
the Argmax local server or any localhost HTTP bridge.

This gives Murmur a second on-device STT backend alongside Apple Speech:

- Apple Speech remains the default on-device provider.
- WhisperKit provides a controllable Whisper model path for offline, BYOK-free
  transcription on supported Apple devices.
- Cloud providers remain unchanged.

## Sources

- Argmax WhisperKit blog:
  https://www.argmaxinc.com/blog/whisperkit
- Argmax open-source Swift SDK:
  https://github.com/argmaxinc/argmax-oss-swift
- Argmax open-source Swift SDK release v1.0.0:
  https://github.com/argmaxinc/argmax-oss-swift/releases/tag/v1.0.0
- Argmax supported platforms:
  https://app.argmaxinc.com/docs/wiki/supported-platforms
- Argmax open-source vs Pro SDK:
  https://app.argmaxinc.com/docs/wiki/open-source-vs-pro-sdk

## Non-Goals

- Do not depend on Argmax Local Server for this provider.
- Do not bundle model weights in the app.
- Do not add Argmax Pro SDK or API-key licensed features.
- Do not add speaker diarization, TTSKit, or SpeakerKit wiring.

## Product Behavior

### Provider Selection

Settings adds a new STT option:

- `WhisperKit (on-device)`

When selected, Murmur records audio through the existing shared audio capture
path and transcribes it locally with WhisperKit.

### Transcription Timing

WhisperKit uses Murmur's existing `SttProvider` stream contract:

1. `startSession()` prepares an empty audio buffer.
2. `sendAudio(_:)` appends 16 kHz mono PCM samples to that buffer while a
   background hypothesis loop periodically transcribes the current buffer.
3. The hypothesis loop emits `.partial` events for the current unstable suffix
   and `.committed` events when segment prefixes agree across passes.
4. `stopSession()` runs one final transcription from the last committed segment
   boundary, emits any remaining committed text, then finishes the event stream.

The provider exposes realtime tuning options for the hypothesis pass interval,
minimum buffered sample count, and required stable segment count. It also emits
diagnostic metrics for session lifecycle, audio receipt, realtime/final pass
latency, first partial latency, runtime cache hits, download/load progress, and
native transcription duration. The app routes those metrics to OSLog under
WhisperKit provider/runtime categories for production diagnostics.

The implementation intentionally does not use `AudioStreamTranscriber` because
that SDK actor opens its own microphone. Murmur keeps its shared audio capture
path and layers incremental transcription on top of WhisperKit's native
`transcribe(audioArray:)` API.

### Defaults

Default model:

- `large-v3-v20240930_626MB`

Rationale: Argmax recommends this model for multilingual accuracy. Users can
override it for debugging or faster startup with values such as `tiny`.

Default repo:

- `argmaxinc/whisperkit-coreml`

Default model folder:

- empty, meaning WhisperKit manages download and cache location.

### Language

Reuse Murmur's existing `sttLanguage` setting:

- `"auto"` maps to `nil`, allowing WhisperKit to detect the language.
- ISO 639-1 values like `"en"`, `"zh"`, `"ja"` map to
  `DecodingOptions(language:)`.

### Model Download and Loading

WhisperKit may download and compile model assets on first use. Murmur wraps the
native SDK in a shared runtime store so the expensive `WhisperKit` pipeline can
stay alive across short-lived recording providers.

For remote models, Murmur downloads through `WhisperKit.download(...)` first so
Settings can show progress. It then initializes `WhisperKit` with the resolved
local model folder, `load: true`, and `download: false`.

The `prewarm` toggle enables proactive loading:

- On app launch and config changes, if WhisperKit is the selected STT provider
  and `prewarm` is enabled, Murmur schedules a debounced background preload.
- Settings exposes a manual load button with download/load/prewarm/ready states.
- Recording still works without preloading; the stop-time transcription path
  initializes the same shared runtime on demand.

### Model Management UI

Settings manages the selected WhisperKit model without requiring a recording
session:

- Show a supported-model picker seeded from WhisperKit's offline model catalog
  plus Murmur's configured/recommended defaults.
- Keep a custom model field for advanced or newly published model IDs.
- Show whether the selected model is cached, missing, or ready from a custom
  local folder.
- Display local cache size and cache path when available.
- Let users pick a custom local model folder and clear it to return to the
  default cache-managed path.
- Let users open the selected cache/local-folder location in Finder when a path
  is available.
- Delete only Murmur-selected remote-model cache folders; never delete a custom
  local model folder supplied by the user.
- Show deletion progress and actionable errors for unavailable folders,
  unsupported platforms, and failed deletes.
- Recheck model inventory when model, repo, or local folder settings change.

## Configuration

Add a new config object:

```swift
public struct WhisperKitSttConfig: Codable, Sendable {
    public var model: String
    public var modelRepo: String
    public var modelFolder: String
    public var prewarm: Bool
    public var realtimeIntervalMilliseconds: Int
    public var realtimeMinimumSamples: Int
    public var realtimeRequiredSegmentsForConfirmation: Int
}
```

Defaults:

```swift
model: "large-v3-v20240930_626MB"
modelRepo: "argmaxinc/whisperkit-coreml"
modelFolder: ""
prewarm: false
realtimeIntervalMilliseconds: 1500
realtimeMinimumSamples: 16000
realtimeRequiredSegmentsForConfirmation: 2
```

Add a provider enum case:

```swift
case whisperKit
```

Backwards compatibility:

- Existing configs without `whisper_kit_stt_config` decode with defaults.
- Existing selected providers remain unchanged.
- No migration is required for cloud keys.

## Implementation Plan

### Phase 1: Package and Domain

- Add `argmax-oss-swift` as a `MurmurKit` Swift package dependency.
- Add the `WhisperKit` product to the `MurmurKit` target.
- Add `SttProviderType.whisperKit`.
- Add `WhisperKitSttConfig` to `AppConfig`.
- Add default constants to `ProviderDefaults`.
- Add config round-trip tests.

### Phase 2: Provider

- Add `MurmurKit/Sources/STT/WhisperKitProvider.swift`.
- Implement it as an actor conforming to `SttProvider`.
- Convert samples with:

```swift
Float(sample) / Float(Int16.max)
```

- Initialize native `WhisperKit` lazily through a shared runtime store and reuse
  the runtime across session-scoped providers.
- Build `WhisperKitConfig` from `WhisperKitSttConfig`.
- Build `DecodingOptions` with the current language hint.
- Emit `.partial` events while recording and `.committed` events for stable
  segments.
- Finish `events` at the end of `stopSession()`.

### Phase 3: Factory and Settings UI

- Map `.whisperKit` in `ProviderFactory`.
- Add Settings fields for:
  - model
  - model repo
  - local model folder, optional
  - prewarm toggle
- Add a supported-model picker plus a custom model field.
- Keep the existing language picker visible for WhisperKit.
- Do not show API-key fields for WhisperKit.
- Add model load status and a manual load button for WhisperKit.
- Add selected-model cache status, cache size/path, refresh, open, delete,
  local folder picker, and local folder validation.
- Add realtime partial tuning controls for pass interval, minimum buffered
  samples, and stable segment confirmation count.

### Phase 3.5: Runtime Reuse and Preload

- Add `WhisperKitRuntimeStore`.
- Key reusable runtimes by normalized model, repo, and local model folder.
- Keep `WhisperKitProvider` session-scoped while moving native pipeline reuse
  into the runtime store.
- Surface download/loading/prewarming/ready/error states.
- Debounce automatic preload when `prewarm` is enabled.

### Phase 3.75: Realtime Partials

- Add a realtime hypothesis state machine for WhisperKit segments.
- Periodically transcribe the current audio buffer while recording.
- Confirm only stable segment prefixes and keep the unstable suffix as partial
  text.
- Run a final stop-time transcription to commit remaining unconfirmed text.
- Add realtime tuning options and metrics for first-partial latency,
  realtime/final pass duration, runtime cache reuse, model load, and native
  transcription duration.
- Persist realtime tuning options in `WhisperKitSttConfig` and pass them
  through `ProviderFactory`.
- Route provider and runtime metrics from recording, manual load, and automatic
  prewarm paths to OSLog.
- Surface the latest provider/runtime diagnostics in Settings so recent
  download, load, transcription, first-partial, cache-hit, and error metrics are
  visible without opening Console.

### Phase 4: Documentation and Tests

- Update README feature list and dependency note.
- Update provider mapping tests.
- Add construction/unit tests for `WhisperKitProvider` that do not download
  models.
- Add unit tests for model-name normalization, local folder validation, and
  cache-size display.
- Add an opt-in integration test for real tiny-model download, cache detection,
  targeted cache deletion, and sibling-folder preservation under a temporary
  home.
- Add an opt-in integration test for real tiny-model provider transcription
  using JFK audio, including realtime partial output, final committed text, and
  special-token filtering.
- Add an opt-in expanded transcription matrix for the real tiny model covering
  English realtime partials, Spanish explicit language, Spanish auto language
  detection, Japanese explicit language, and local model-folder transcription
  from the downloaded cache. Run it with
  `MURMUR_RUN_WHISPERKIT_TRANSCRIPTION_MATRIX_E2E=1`.
- Add an opt-in production-default model transcription E2E path for the heavier
  default WhisperKit model. Run it with
  `MURMUR_RUN_WHISPERKIT_DEFAULT_MODEL_E2E=1`.
- Verify realtime partial metrics with the real transcription E2E path.
- Verify OSLog metric routing compiles through package tests and the app target
  build.
- Verify the app diagnostics recorder receives provider metrics through
  `ProviderFactory`.
- Add unit tests for the diagnostics snapshot reducer.
- Add macOS UI automation for the in-app diagnostics panel, including seeded
  metrics and reset behavior.
- Run package tests.

## Acceptance Criteria

- `swift test --package-path MurmurKit` passes.
- `ProviderFactory` returns `WhisperKitProvider` for `.whisperKit`.
- `AppConfig` JSON round-trips `whisper_kit_stt_config`.
- Older `whisper_kit_stt_config` JSON without realtime fields still decodes
  with safe defaults.
- Existing provider configs still decode.
- Settings exposes WhisperKit as an on-device STT provider.
- Settings can proactively load the selected WhisperKit model.
- Settings exposes supported-model selection, custom model entry, selected-model
  cache status, and cache deletion for remote cached models.
- Settings exposes WhisperKit realtime partial tuning controls.
- WhisperKit emits partial text while recording once the model is loaded.
- No Argmax local server is required.

## Known Risks

- First-use model download and Core ML compilation may be slow.
- Realtime partials are implemented by periodic native buffer transcription,
  not by an SDK-provided incremental decoder. Latency and CPU usage depend on
  the selected model and device.
- Runtime reuse is scoped to a process session. Model files and Core ML
  specialization are cached on disk by the underlying systems, but the in-memory
  `WhisperKit` pipeline is recreated after app restart.
- Cache management is intentionally scoped to the selected remote-model folder
  under WhisperKit/Hugging Face cache locations. User-supplied local folders are
  validated but never deleted by Murmur.
- Adding WhisperKit changes `MurmurKit` from zero-dependency to a package with a
  native ML dependency tree.
- WhisperKit v1.0.0 is a breaking release from the old `argmaxinc/WhisperKit`
  package name. The package URL must be `argmaxinc/argmax-oss-swift`.
