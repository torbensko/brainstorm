#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."

configuration="${CONFIGURATION:-release}"
sdk_version="$(xcrun --sdk macosx --show-sdk-version)"
deployment_target="$(/usr/libexec/PlistBuddy -c 'Print :LSMinimumSystemVersion' resources/Info.plist)"
# The SwiftPM linker can stamp the deployment target as the SDK version, opting out of modern AppKit UI.
# Keep backwards compatibility while advertising the SDK we actually build against.
swift build -c "$configuration" -Xlinker -platform_version -Xlinker macos -Xlinker "$deployment_target" -Xlinker "$sdk_version"
binary_directory="$(swift build -c "$configuration" --show-bin-path)"
recorded_sdk="$(xcrun vtool -show-build "$binary_directory/Brainstorm" | awk '$1 == "sdk" { print $2; exit }')"
if [[ "$recorded_sdk" != "$sdk_version" ]]; then
    printf 'SDK metadata mismatch: built with %s, executable reports %s\n' "$sdk_version" "$recorded_sdk" >&2
    exit 1
fi
app_directory="$PWD/dist/Brainstorm.app"
mkdir -p "$app_directory/Contents/MacOS" "$app_directory/Contents/Resources"
# Replace the file rather than overwriting code that a running app may have mapped.
cp "$binary_directory/Brainstorm" "$app_directory/Contents/MacOS/Brainstorm.new"
mv -f "$app_directory/Contents/MacOS/Brainstorm.new" "$app_directory/Contents/MacOS/Brainstorm"
cp resources/Info.plist "$app_directory/Contents/Info.plist"
/usr/libexec/PlistBuddy -c "Add :BrainstormSourceRevision string $(git rev-parse --short=8 HEAD)" "$app_directory/Contents/Info.plist"
/usr/libexec/PlistBuddy -c "Add :BrainstormBuildDate string $(date -u '+%Y-%m-%d %H:%M UTC')" "$app_directory/Contents/Info.plist"
cp resources/AppIcon.icns "$app_directory/Contents/Resources/AppIcon.icns"
codesign --force --options runtime --sign "${CODE_SIGN_IDENTITY:--}" "$app_directory"
codesign --verify --deep --strict "$app_directory"
ditto -c -k --keepParent "$app_directory" dist/Brainstorm-macOS.zip

if [[ -n "${NOTARY_PROFILE:-}" ]]; then
    xcrun notarytool submit dist/Brainstorm-macOS.zip --keychain-profile "$NOTARY_PROFILE" --wait
    xcrun stapler staple "$app_directory"
    ditto -c -k --keepParent "$app_directory" dist/Brainstorm-macOS.zip
fi
printf 'Built %s\n' "$app_directory"
