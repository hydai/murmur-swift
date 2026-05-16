#!/usr/bin/env bash
#
# Build a distributable DMG from the already-built Murmur.app.
#
# Usage:
#   scripts/build-dmg.sh <app_path> <output_dmg>
#
# Requires `create-dmg` (brew install create-dmg). Produces a styled
# DMG with a Applications drag link.

set -euo pipefail

APP_PATH="${1:?usage: $0 <Murmur.app path> <output.dmg>}"
OUTPUT_DMG="${2:?usage: $0 <Murmur.app path> <output.dmg>}"

if [[ ! -d "$APP_PATH" ]]; then
  echo "error: app bundle not found at $APP_PATH" >&2
  exit 1
fi

if ! command -v create-dmg >/dev/null 2>&1; then
  echo "error: create-dmg is not installed. Run: brew install create-dmg" >&2
  exit 1
fi

VOLUME_NAME="Murmur"

# create-dmg is interactive in some failure modes; force the no-prompt path.
rm -f "$OUTPUT_DMG"

create-dmg \
  --volname "$VOLUME_NAME" \
  --window-pos 200 120 \
  --window-size 600 400 \
  --icon-size 100 \
  --icon "Murmur.app" 150 200 \
  --hide-extension "Murmur.app" \
  --app-drop-link 450 200 \
  --hdiutil-quiet \
  "$OUTPUT_DMG" \
  "$APP_PATH"

echo "Created $OUTPUT_DMG"
