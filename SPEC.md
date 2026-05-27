# Murmur Multi-Platform Specification

## Goal

Ship Murmur as one shared Swift codebase deployed to:

- macOS
- iOS
- iPadOS

The first mobile milestone is a native iOS/iPadOS app for voice typing into Murmur itself, then copying or sharing the processed text. macOS keeps the current menu bar, global hotkey, overlay, and Accessibility keyboard injection workflow.

## Product Constraints

- Require current Apple platform versions. Backward compatibility with old OS versions is not a goal.
- iOS and iPadOS cannot provide the same system-wide behavior as macOS. There is no supported equivalent to a global hotkey plus arbitrary keyboard event injection into other apps.
- A custom keyboard extension cannot record audio, so mobile dictation must happen in the containing app. A future keyboard extension may insert cached or shared text, but it must not be treated as the primary recording surface.
- Cloud providers remain BYOK. On-device Apple STT and Apple Foundation Models remain the preferred default where available.

## Target User Experience

### macOS

- Existing behavior remains the reference experience.
- Menu bar controls, configurable global hotkey, floating overlay, sounds, settings, history, Sparkle updates, and keyboard/clipboard output remain available.

### iOS

- Main app opens directly to recording.
- User taps Record, speaks, taps Stop, then sees raw and processed text.
- Output actions are mobile-native: copy to clipboard and share through the system share sheet.
- History and Settings are reachable as first-class tabs.
- Settings hide or disable unsupported desktop-only options.

### iPadOS

- Same functional behavior as iOS.
- Layout should adapt to larger displays by using split navigation where appropriate.
- Hardware keyboard shortcuts may toggle recording only while Murmur is the foreground app.

## Architecture

### Shared Core

`MurmurKit` remains the shared foundation:

- Audio capture, resampling, VAD
- STT provider protocols and implementations
- LLM provider protocols and implementations
- Pipeline orchestration
- Config, history, prompts, dictionary
- Output abstractions

Shared code must compile for macOS and iOS. Platform-only capabilities are isolated behind conditional compilation or small capability abstractions.

### Platform Capability Layer

Add a simple capability surface for UI and factory decisions:

- `supportsGlobalHotkey`
- `supportsKeyboardInjection`
- `supportsClipboardOutput`
- `supportsCLIProcessors`
- `supportsSparkleUpdates`
- `supportsModelDownloads`

UI must use capabilities rather than hard-coded platform assumptions wherever the behavior differs.

### Platform App Shells

- macOS keeps the current `AppDelegate` and menu bar app lifecycle.
- iOS/iPadOS uses a normal SwiftUI app shell with tabs:
  - Record
  - History
  - Settings

The shared `MurmurApp` entry point selects the platform shell with `#if os(macOS)`.

### Output Model

Keep `OutputMode` for config compatibility, but map unsupported modes safely:

- macOS:
  - clipboard
  - keyboard simulation
  - both
- iOS/iPadOS:
  - clipboard
  - keyboard and both degrade to clipboard until a mobile-specific output model is added

Settings must not present keyboard simulation as a normal mobile option.

### Provider Availability

STT:

- Apple Speech: available on supported devices and locales.
- Cloud STT providers: available on mobile if network and API keys are configured.
- Custom local STT endpoint: allowed in config but localhost is usually not useful on a phone; UI copy should make this clear in a later UX pass.

LLM:

- Apple Foundation Models: available only when the device supports Apple Intelligence and the model is ready.
- Cloud LLM providers: available on mobile if network and API keys are configured.
- CLI processors: macOS-only. iOS/iPadOS must hide Gemini CLI and Copilot CLI and must not instantiate them.

### Permissions

macOS:

- Microphone
- Speech recognition
- Accessibility for keyboard simulation

iOS/iPadOS:

- Microphone
- Speech recognition
- Network client through normal app sandbox behavior

Audio capture on iOS/iPadOS must configure `AVAudioSession` before starting `AVAudioEngine`.

## Implementation Plan

### Phase 1: Compile-Oriented Platformization

Acceptance criteria:

- `SPEC.md` exists and documents the multi-platform plan.
- `MurmurKit` still builds on macOS.
- Shared app code no longer hardcodes AppKit in files that compile for iOS.
- iOS/iPadOS has a SwiftUI app shell source path.
- macOS app behavior remains wired to existing managers.

Tasks:

- Add platform capability definitions.
- Add iOS root view with tab navigation.
- Make settings colors platform-aware.
- Make About, Output, Hotkey, and LLM settings platform-aware.
- Configure iOS audio session before recording.
- Add iOS Info.plist build settings and entitlements placeholders.
- Add an iOS app target to the Xcode project.

### Phase 2: Mobile MVP

Acceptance criteria:

- App launches on iPhone and iPad simulator/device.
- Recording works with Apple Speech after permissions are granted.
- Cloud STT and LLM settings save and are used by the next recording.
- Final text can be copied.
- History persists and can copy/delete entries.

Tasks:

- Run and fix iOS build once the iOS platform runtime is available in Xcode.
- Add mobile permission prompts and error recovery UI.
- Save transcription history from the iOS root flow.
- Hide or migrate unsupported config values.
- Add iPad layout polish.

### Phase 3: Mobile Output Expansion

Acceptance criteria:

- Share sheet output is available on iOS/iPadOS.
- Output settings use mobile-specific language.
- Clipboard behavior is explicit and reliable.

Tasks:

- Add a `ShareOutput` or app-level share action.
- Consider replacing `OutputMode` with a platform-aware output preferences model while preserving config migration.
- Add tests for platform output fallback behavior.

### Phase 4: Optional Keyboard Extension

Acceptance criteria:

- Keyboard extension inserts text from a shared app group container.
- Keyboard extension clearly directs recording to the containing app.
- No microphone recording is attempted from the keyboard extension.

Tasks:

- Add app group entitlement.
- Persist most recent processed transcript to the app group.
- Add a minimal keyboard extension UI for inserting latest text and switching keyboards.

### Phase 5: Mobile Hardening

Acceptance criteria:

- Mobile settings expose keyboard extension readiness without requiring Xcode logs.
- App group write failures do not silently fall back to private app defaults.
- Users have a direct path from Murmur to the relevant iOS settings page.

Tasks:

- Add a mobile keyboard extension status card in Output settings.
- Show shared container availability and latest transcript sync state.
- Add an App Settings action for enabling the keyboard and Full Access.
- Make latest-transcript writes report whether the shared app group store was available.

## Verification Plan

Local verification:

- `swift build --package-path MurmurKit`
- `swift test --package-path MurmurKit`
- `xcodebuild -workspace Murmur.xcworkspace -scheme Murmur -configuration Debug build`
- iOS simulator build:
  - `xcodebuild -project Murmur.xcodeproj -scheme "Murmur iOS" -destination 'platform=iOS Simulator,name=iPhone 17,OS=26.4.1' build`
  - `xcodebuild -project Murmur.xcodeproj -scheme "Murmur iOS" -destination 'platform=iOS Simulator,name=iPad Pro 13-inch (M5),OS=26.4.1' build`
- iOS device build without signing, for compile/package validation:
  - `xcodebuild -project Murmur.xcodeproj -scheme "Murmur iOS" -destination generic/platform=iOS build CODE_SIGNING_ALLOWED=NO`

Manual verification:

- macOS existing hotkey and menu bar workflow.
- macOS Accessibility output still types into another focused app.
- iOS recording permission prompt appears.
- iOS record/stop pipeline returns transcript.
- iOS unsupported options are hidden from Settings.
- iOS/iPadOS share buttons present the system share sheet for completed transcripts and history rows.
- iOS keyboard extension appears after installation, requires Full Access, reads the latest processed transcript, and inserts it into a focused text field.
- iOS Output settings show keyboard extension shared-container status and latest transcript sync state.

## Risks

- Apple Foundation Models availability varies by device eligibility, Apple Intelligence settings, and model readiness.
- Apple Speech model availability and locale support vary by OS and device.
- iOS custom keyboard limitations prevent full macOS-style system-wide voice typing.
- Xcode project changes for a second target need validation in an installed iOS toolchain.
- The keyboard extension app group must be registered in the Apple Developer portal for signed device builds, and users must enable Full Access before the keyboard can read the shared container.

## Current Implementation Status

- Phase 1 is implemented and locally validated:
  - platform capability flags
  - iOS/iPadOS SwiftUI tab shell
  - iOS audio-session setup before recording
  - mobile-safe output and settings fallbacks
  - macOS-only CLI processor isolation
  - `Murmur iOS` Xcode target and shared scheme
- Latest validation:
  - `swift build --package-path MurmurKit` succeeds.
  - `swift test --package-path MurmurKit` passes with 120 tests.
  - `Murmur iOS` builds for iPhone 17 Simulator and iPad Pro 13-inch (M5) Simulator on iOS 26.4.1, including the embedded keyboard extension.
  - `Murmur iOS` builds for generic iOS devices with `CODE_SIGNING_ALLOWED=NO`, including the embedded keyboard extension.
  - macOS `Murmur` scheme builds successfully.
- Full signed device builds require setting `DEVELOPMENT_TEAM` on the `Murmur iOS` and `MurmurKeyboardExtension` targets and registering the `group.com.hydai.Murmur` app group.
- Phase 2 is implemented, with manual speech/provider verification still pending:
  - iPhone and iPad simulator install/launch validation succeeds with `xcrun simctl launch`.
  - Mobile permission UX now tracks Microphone and Speech Recognition, gates recording, and opens Settings when access is blocked.
  - Apple Speech provider now requests Speech Recognition authorization before starting a session.
  - iPad regular-width layouts use split navigation instead of only a tab shell.
  - iOS history save path now loads persisted history before adding a recording result, and History rows support mobile swipe copy/delete actions.
  - Unsupported LLM/output config values normalize to current-platform-supported values before use or save.
  - Remaining manual verification: grant permissions on simulator/device, speak into the microphone, confirm Apple Speech returns a transcript, confirm cloud STT/LLM settings are used by the next recording, and confirm copy/history behavior from the running app UI.
- Phase 3 is implemented and locally validated:
  - Completed transcripts expose Copy and Share actions on iOS/iPadOS.
  - History rows expose visible Share actions and mobile swipe Share actions.
  - Output settings use mobile-specific Copy and Share language.
  - `OutputMode` now exposes platform-aware normalization and available-mode helpers.
  - Output fallback tests cover mobile clipboard-only behavior and desktop mode preservation.
  - Remaining manual verification: tap Share in the running simulator/device UI and confirm the system share sheet presents correctly on iPhone and iPad.
- Phase 4 is implemented as a first pass and locally validated:
  - `MurmurKeyboardExtension` target and scheme are present in the Xcode project.
  - The iOS app and keyboard extension both declare the `group.com.hydai.Murmur` app group entitlement.
  - The iOS app writes each completed processed transcript to the shared app group defaults store.
  - The keyboard extension reads the latest processed transcript, inserts it into the active text field, and includes a Next Keyboard control.
  - The keyboard extension does not request or use microphone access.
  - iPhone and iPad simulator install/launch validation succeeds after embedding the keyboard extension.
  - Remaining manual verification: enable the Murmur keyboard with Full Access in Settings, record a transcript in the app, switch to the keyboard in another text field, and confirm Insert Latest inserts the shared text.
- Phase 5 is implemented as a first hardening pass:
  - Mobile Output settings include a Keyboard Extension card.
  - The card reports shared app group container availability and latest transcript sync state.
  - The card can open the app's iOS Settings page for keyboard enablement and Full Access.
  - Latest-transcript writes now fail explicitly when the shared app group store is unavailable instead of falling back to private app defaults.
  - Remaining manual verification: open Output settings on device/simulator after recording and confirm the card changes from Not synced yet to Synced.
