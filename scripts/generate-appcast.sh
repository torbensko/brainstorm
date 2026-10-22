#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."

version="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' resources/Info.plist)"
artifact="Brainstorm-$version-macOS-arm64"
feed_directory="$(mktemp -d "$PWD/dist/sparkle.XXXXXX")"
trap 'rm -rf "$feed_directory"' EXIT
test -f "dist/$artifact.zip"
cp "dist/$artifact.zip" "$feed_directory/"
cp "releases/$version.md" "$feed_directory/$artifact.md"

arguments=(
    --download-url-prefix "https://github.com/torbensko/brainstorm/releases/download/v$version/"
    --embed-release-notes
    --link "https://torbensko.com/software/brainstorm/"
    --maximum-deltas 0
    "$feed_directory"
)
tool="$PWD/.build/artifacts/sparkle/Sparkle/bin/generate_appcast"
if [[ -n "${SPARKLE_PRIVATE_KEY:-}" ]]; then
    printf '%s' "$SPARKLE_PRIVATE_KEY" | "$tool" --ed-key-file - "${arguments[@]}"
else
    "$tool" --account app.brainstorm.native "${arguments[@]}"
fi
cp "$feed_directory/appcast.xml" dist/appcast.xml

# Ensure the feed cannot advertise a different build, URL, or unsigned archive.
python3 scripts/validate-appcast.py dist/appcast.xml resources/Info.plist "dist/$artifact.zip"
