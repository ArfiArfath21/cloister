#!/bin/bash
# Builds build/Cloister.app as a universal (arm64 + x86_64), ad-hoc signed app.
#
#   ./build.sh          build the app
#   ./build.sh --zip    also package build/Cloister.zip for a release
set -euo pipefail
cd "$(dirname "$0")"

ZIP=0
for arg in "$@"; do
  case "$arg" in
    --zip) ZIP=1 ;;
    *) echo "unknown option: $arg" >&2; exit 1 ;;
  esac
done

APP=build/Cloister.app
rm -rf build
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources" build/obj

for arch in arm64 x86_64; do
  swiftc -O -swift-version 5 \
    -target "$arch-apple-macos13" \
    Sources/*.swift \
    -o "build/obj/Cloister-$arch"
done
lipo -create build/obj/Cloister-* -output "$APP/Contents/MacOS/Cloister"
rm -rf build/obj

cp Info.plist "$APP/Contents/Info.plist"
cp Resources/AppIcon.icns "$APP/Contents/Resources/AppIcon.icns"
codesign --force --sign - "$APP"

if [ "$ZIP" = 1 ]; then
  ditto -c -k --keepParent "$APP" build/Cloister.zip
  echo "Packaged build/Cloister.zip"
fi

echo "Built $APP"
