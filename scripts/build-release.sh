#!/bin/bash
set -euo pipefail

repo_root="$(cd "$(dirname "$0")/.." && pwd)"
release_tag="${1:-v0.1.5}"
if [[ ! "$release_tag" =~ ^v[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
    echo "Expected a version such as v0.1.5" >&2
    exit 1
fi
release_dir="$repo_root/build/releases/$release_tag"
if [[ -e "$release_dir/Pin.app" ]]; then
    echo "Build output already exists: $release_dir/Pin.app" >&2
    exit 1
fi
mkdir -p "$release_dir"
staging_dir="$(mktemp -d "$release_dir/staging.XXXXXX")"
app_path="$staging_dir/Pin.app"
mkdir -p "$app_path/Contents/MacOS" "$app_path/Contents/Resources"

cd "$repo_root"
swift build -c release --arch arm64 -Xswiftc -warnings-as-errors
binary_dir="$(swift build -c release --arch arm64 --show-bin-path)"
install -m 755 "$binary_dir/Pin" "$app_path/Contents/MacOS/Pin"
cp Resources/Info.plist "$app_path/Contents/Info.plist"
/usr/libexec/PlistBuddy -c "Set :CFBundleShortVersionString ${release_tag#v}" "$app_path/Contents/Info.plist"
iconutil -c icns Resources/AppIcon.iconset -o "$app_path/Contents/Resources/AppIcon.icns"
printf 'APPL????' > "$app_path/Contents/PkgInfo"

codesign --force --sign - --timestamp=none "$app_path"
codesign --verify --deep --strict --verbose=2 "$app_path"
plutil -lint "$app_path/Contents/Info.plist"
[[ "$(xcrun lipo -archs "$app_path/Contents/MacOS/Pin")" == arm64 ]]
[[ "$("$app_path/Contents/MacOS/Pin" --version)" == "${release_tag#v}" ]]
mv "$app_path" "$release_dir/Pin.app"
archive="Pin-$release_tag-macos-arm64.zip"
ditto -c -k --keepParent "$release_dir/Pin.app" "$release_dir/$archive"
(cd "$release_dir" && shasum -a 256 "$archive" > "$archive.sha256")
echo "Built $release_dir/$archive"
