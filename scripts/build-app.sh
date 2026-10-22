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
mkdir -p "$app_directory/Contents/MacOS" "$app_directory/Contents/Resources" "$app_directory/Contents/Frameworks"
# Replace the file rather than overwriting code that a running app may have mapped.
cp "$binary_directory/Brainstorm" "$app_directory/Contents/MacOS/Brainstorm.new"
mv -f "$app_directory/Contents/MacOS/Brainstorm.new" "$app_directory/Contents/MacOS/Brainstorm"
cp resources/Info.plist "$app_directory/Contents/Info.plist"
/usr/libexec/PlistBuddy -c "Add :BrainstormSourceRevision string $(git rev-parse --short=8 HEAD)" "$app_directory/Contents/Info.plist"
/usr/libexec/PlistBuddy -c "Add :BrainstormBuildDate string $(date -u '+%Y-%m-%d %H:%M UTC')" "$app_directory/Contents/Info.plist"
cp resources/AppIcon.icns "$app_directory/Contents/Resources/AppIcon.icns"

# SwiftPM links the binary framework but does not embed it in our hand-built bundle.
sparkle_source="$PWD/.build/artifacts/sparkle/Sparkle/Sparkle.xcframework/macos-arm64_x86_64/Sparkle.framework"
sparkle_framework="$app_directory/Contents/Frameworks/Sparkle.framework"
test -d "$sparkle_source"
rm -rf "$sparkle_framework"
ditto "$sparkle_source" "$sparkle_framework"
cp .build/artifacts/sparkle/Sparkle/LICENSE "$app_directory/Contents/Resources/Sparkle-LICENSE.txt"

identity="${CODE_SIGN_IDENTITY:--}"
signing_options=(--force --sign "$identity")
if [[ "$identity" == "-" ]]; then
    # Ad-hoc development signatures have no Team ID for hardened library validation.
    signing_options+=(--options 0)
else
    signing_options+=(--options runtime --timestamp)
fi
# Sign from the inside out; --deep is for verification, never for distribution signing.
codesign "${signing_options[@]}" "$sparkle_framework/Versions/B/XPCServices/Installer.xpc"
codesign "${signing_options[@]}" --preserve-metadata=entitlements "$sparkle_framework/Versions/B/XPCServices/Downloader.xpc"
codesign "${signing_options[@]}" "$sparkle_framework/Versions/B/Autoupdate"
codesign "${signing_options[@]}" "$sparkle_framework/Versions/B/Updater.app"
codesign "${signing_options[@]}" "$sparkle_framework"
codesign "${signing_options[@]}" "$app_directory"
codesign --verify --deep --strict "$app_directory"
ditto -c -k --keepParent "$app_directory" dist/Brainstorm-macOS.zip

if [[ -n "${NOTARY_PROFILE:-}" ]]; then
    xcrun notarytool submit dist/Brainstorm-macOS.zip --keychain-profile "$NOTARY_PROFILE" --wait
    xcrun stapler staple "$app_directory"
    ditto -c -k --keepParent "$app_directory" dist/Brainstorm-macOS.zip
fi
printf 'Built %s\n' "$app_directory"
