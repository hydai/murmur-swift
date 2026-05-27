# Distribution

How Murmur is built, signed, and shipped.

## Distribution channels

- **Direct download** of the DMG from GitHub Releases (`Murmur-macOS.dmg`)
- **Homebrew cask** via the `hydai/homebrew-murmur-swift` tap (once configured):
  ```bash
  brew tap hydai/murmur-swift
  brew install --cask murmur-swift
  ```
- **In-app auto-update** via Sparkle once the appcast is published alongside each release

## End-user install notes

The DMG is built unsigned by default. If you install it without notarization, macOS Gatekeeper will block the first launch. Fix:

```bash
xattr -cr /Applications/Murmur.app
```

Releases that ship with notarization (see "Release secrets" below) skip this step.

After installation, grant the macOS permissions when prompted:

1. **Microphone** — for audio capture (Settings → Privacy & Security → Microphone)
2. **Speech Recognition** — required when using Apple Speech (Settings → Privacy & Security → Speech Recognition)
3. **Accessibility** — only required if you use "Keyboard" output mode (Settings → Privacy & Security → Accessibility)

## Local builds

```bash
# Build the .app bundle
xcodebuild -workspace Murmur.xcworkspace -scheme Murmur -configuration Release build

# Package the built app as a DMG
APP=$(find ~/Library/Developer/Xcode/DerivedData -name 'Murmur.app' -type d | head -1)
scripts/build-dmg.sh "$APP" Murmur-macOS.dmg
```

`scripts/build-dmg.sh` requires `create-dmg`:

```bash
brew install create-dmg
```

## Release workflow

`.github/workflows/release.yml` runs on every push to `master`.

1. **Prepare-release PR** — if the head commit does NOT start with `chore: prepare release`, Knope opens a release PR that bumps `MARKETING_VERSION` and updates `CHANGELOG.md`.
2. **Build, sign, notarize, release** — when the release PR is merged (its merge commit starts with `chore: prepare release`):
   - Resolves Swift Package dependencies (including Sparkle)
   - Imports the signing certificate (if configured)
   - Builds Murmur.app (signed if `MACOS_SIGN_IDENTITY` is set, ad-hoc otherwise)
   - Packages a DMG via `scripts/build-dmg.sh`
   - Notarizes the DMG with `notarytool` and staples the ticket (if Apple ID secrets are set)
   - Signs the update with Sparkle's `sign_update` and writes `artifacts/sparkle-signature.txt`
   - Creates the GitHub Release via Knope, attaching the DMG
   - Updates the `hydai/homebrew-murmur-swift` cask (if `HOMEBREW_TAP_TOKEN` is set)

Each step is independently conditioned on its secrets being present, so the workflow degrades gracefully to an ad-hoc-signed DMG release until the credentials are provisioned.

## Release secrets

Add these in **Settings → Secrets and variables → Actions** to unlock the full pipeline:

| Secret                          | Purpose                                                                                  |
|---------------------------------|------------------------------------------------------------------------------------------|
| `MACOS_CERTIFICATE`             | Developer ID Application .p12, base64-encoded (`base64 -i cert.p12 \| pbcopy`)           |
| `MACOS_CERTIFICATE_PWD`         | Passphrase for the .p12                                                                  |
| `MACOS_SIGN_IDENTITY`           | Identity string, e.g. `Developer ID Application: Your Name (TEAMID)`                     |
| `MACOS_NOTARIZATION_APPLE_ID`   | Apple ID used for notarization (`notarytool` `--apple-id`)                               |
| `MACOS_NOTARIZATION_TEAM_ID`    | Apple Developer Team ID                                                                  |
| `MACOS_NOTARIZATION_PWD`        | App-specific password generated at <https://appleid.apple.com>                           |
| `SPARKLE_PRIVATE_KEY`           | The EdDSA private key emitted by Sparkle's `generate_keys` tool                          |
| `HOMEBREW_TAP_TOKEN`            | Personal access token with write access to `hydai/homebrew-murmur-swift`                 |

### Sparkle key setup

1. Resolve packages once locally so `sign_update` and `generate_keys` are available in DerivedData:
   ```bash
   xcodebuild -resolvePackageDependencies -project Murmur.xcodeproj -scheme Murmur
   ```
2. Generate the EdDSA key pair:
   ```bash
   GK=$(find ~/Library/Developer/Xcode/DerivedData -name generate_keys -type f | head -1)
   "$GK"
   ```
   The tool prints the **public key**. Paste it into `MurmurApp/Resources/Info.plist` as the value of `SUPublicEDKey` and commit. It also stores the **private key** in your Keychain — export it with `"$GK" -p > sparkle-private.pem` and add the PEM contents as the `SPARKLE_PRIVATE_KEY` secret.
3. The release workflow's "Sign update with Sparkle" step reads the secret, signs the DMG, and writes the signature to `artifacts/sparkle-signature.txt`. The appcast XML you commit alongside each release must reference that signature.

## Appcast layout

A minimal `appcast.xml` lives at `https://github.com/hydai/murmur-swift/releases/latest/download/appcast.xml` (uploaded by the release workflow). Each release item looks like:

```xml
<item>
  <title>1.2.3</title>
  <sparkle:version>1.2.3</sparkle:version>
  <pubDate>Mon, 17 May 2026 00:00:00 +0000</pubDate>
  <enclosure
    url="https://github.com/hydai/murmur-swift/releases/download/v1.2.3/Murmur-macOS.dmg"
    sparkle:edSignature="…signature from sparkle-signature.txt…"
    length="…bytes…"
    type="application/octet-stream" />
</item>
```

Generate it from a release tag with Sparkle's `generate_appcast` tool against a folder containing the DMG + signature, or hand-write the entry — the format is small.

## Pre-commit hook

Activate the repo's pre-commit hook to run `lineguard`, `swift build -c release`, and `swift test` before every commit:

```bash
git config core.hooksPath .githooks
```
