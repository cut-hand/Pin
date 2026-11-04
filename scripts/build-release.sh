#!/bin/bash
set -euo pipefail

repo_root="$(cd "$(dirname "$0")/.." && pwd)"
release_tag="${1:-v0.1.4-no-badge.1}"
if [[ ! "$release_tag" =~ ^v[0-9]+\.[0-9]+\.[0-9]+(-[A-Za-z0-9.-]+)?$ ]]; then
    echo "Expected a release tag such as v0.1.4-no-badge.1" >&2
    exit 1
fi
bundle_version="${release_tag#v}"
bundle_version="${bundle_version%%-*}"
release_dir="$repo_root/build/releases/$release_tag"
if [[ -e "$release_dir/Pin.app" ]]; then
    echo "Build output already exists: $release_dir/Pin.app" >&2
    exit 1
fi
mkdir -p "$release_dir"
staging_dir="$(mktemp -d "$release_dir/staging.XXXXXX")"
app_path="$staging_dir/Pin.app"
mkdir -p "$app_path/Contents/MacOS" "$app_path/Contents/Resources"

# This fork has no external frameworks and only needs the macOS command line tools.
sources=("$repo_root"/pin-agent/Pin/Sources/App/*.swift
         "$repo_root"/pin-agent/Pin/Sources/Core/*.swift)
for arch in arm64 x86_64; do
    xcrun swiftc -swift-version 5 -O -module-name Pin \
        -target "$arch-apple-macosx14.0" \
        "${sources[@]}" -o "$staging_dir/Pin-$arch"
done
xcrun lipo -create "$staging_dir/Pin-arm64" "$staging_dir/Pin-x86_64" \
    -output "$app_path/Contents/MacOS/Pin"

cp "$repo_root/pin-agent/Pin/Info.plist" "$app_path/Contents/Info.plist"
plist="$app_path/Contents/Info.plist"
/usr/libexec/PlistBuddy -c 'Set :CFBundleExecutable Pin' "$plist"
/usr/libexec/PlistBuddy -c 'Set :CFBundleIdentifier com.southflowpeak.Pin' "$plist"
/usr/libexec/PlistBuddy -c 'Set :CFBundleName Pin' "$plist"
/usr/libexec/PlistBuddy -c "Set :CFBundleShortVersionString $bundle_version" "$plist"
/usr/libexec/PlistBuddy -c 'Set :LSMinimumSystemVersion 14.0' "$plist"
/usr/libexec/PlistBuddy -c 'Add :CFBundleIconFile string AppIcon' "$plist"
/usr/libexec/PlistBuddy -c 'Add :NSHighResolutionCapable bool true' "$plist"
printf 'APPL????' > "$app_path/Contents/PkgInfo"

icon_source="$repo_root/pin-agent/Pin/Resources/Assets.xcassets/AppIcon.appiconset"
iconset="$staging_dir/AppIcon.iconset"
mkdir -p "$iconset"
for size in 16 32 128 256 512; do
    cp "$icon_source/pin-macOS-${size}x${size}@1x.png" "$iconset/icon_${size}x${size}.png"
    if [[ "$size" != 512 ]]; then
        cp "$icon_source/pin-macOS-${size}x${size}@2x.png" "$iconset/icon_${size}x${size}@2x.png"
    fi
done
cp "$icon_source/pin-macOS-1024x1024@1x.png" "$iconset/icon_512x512@2x.png"
iconutil -c icns "$iconset" -o "$app_path/Contents/Resources/AppIcon.icns"

# Ad-hoc signing allows local use without the upstream author's private certificate.
codesign --force --sign - --timestamp=none "$app_path"
codesign --verify --deep --strict --verbose=2 "$app_path"
plutil -lint "$plist"
for arch in arm64 x86_64; do
    xcrun lipo "$app_path/Contents/MacOS/Pin" -verify_arch "$arch"
done
mv "$app_path" "$release_dir/Pin.app"
app_path="$release_dir/Pin.app"

archive="Pin-$release_tag-macos-universal.zip"
ditto -c -k --keepParent "$app_path" "$release_dir/$archive"
(cd "$release_dir" && shasum -a 256 "$archive" > "$archive.sha256")
echo "Built $release_dir/$archive"
