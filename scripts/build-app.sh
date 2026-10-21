#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."

configuration="${CONFIGURATION:-release}"
swift build -c "$configuration"
binary_directory="$(swift build -c "$configuration" --show-bin-path)"
app_directory="$PWD/dist/Brainstorm.app"
mkdir -p "$app_directory/Contents/MacOS" "$app_directory/Contents/Resources"
# Replace the file rather than overwriting code that a running app may have mapped.
cp "$binary_directory/Brainstorm" "$app_directory/Contents/MacOS/Brainstorm.new"
mv -f "$app_directory/Contents/MacOS/Brainstorm.new" "$app_directory/Contents/MacOS/Brainstorm"
cp resources/Info.plist "$app_directory/Contents/Info.plist"
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
