#!/bin/bash
# Builds build/Cloister.app as a universal (arm64 + x86_64), ad-hoc signed app.
#
#   ./build.sh          build the app
#   ./build.sh --dmg    also package build/Cloister.dmg, the drag-to-Applications installer
set -euo pipefail
cd "$(dirname "$0")"

DMG=0
for arg in "$@"; do
  case "$arg" in
    --dmg) DMG=1 ;;
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

echo "Built $APP"

if [ "$DMG" = 1 ]; then
  STAGE=build/dmg
  RW=build/Cloister-rw.dmg
  VOLUME=/Volumes/Cloister
  [ -d "$VOLUME" ] && { echo "Eject the mounted Cloister volume first." >&2; exit 1; }

  mkdir -p "$STAGE/.background"
  cp -R "$APP" "$STAGE/"
  ln -s /Applications "$STAGE/Applications"
  cp Resources/dmg-background.tiff "$STAGE/.background/background.tiff"

  hdiutil create -quiet -volname Cloister -srcfolder "$STAGE" -fs HFS+ -format UDRW -ov "$RW"
  DEVICE=$(hdiutil attach -quiet -readwrite -noverify -noautoopen "$RW" 2>/dev/null; hdiutil info | awk -v v="$VOLUME" '$NF == v {print $1}')

  # Lay out the Finder window: background, icon size and positions.
  osascript <<'APPLESCRIPT'
tell application "Finder"
  tell disk "Cloister"
    open
    set current view of container window to icon view
    set toolbar visible of container window to false
    set statusbar visible of container window to false
    try
      set pathbar visible of container window to false
    end try
    set the bounds of container window to {200, 120, 840, 548}
    set viewOptions to the icon view options of container window
    set arrangement of viewOptions to not arranged
    set icon size of viewOptions to 112
    set text size of viewOptions to 13
    set background picture of viewOptions to file ".background:background.tiff"
    set position of item "Cloister.app" of container window to {160, 180}
    set position of item "Applications" of container window to {480, 180}
    close
    open
    update without registering applications
    delay 1
    close
  end tell
end tell
APPLESCRIPT

  # Volume icon goes in after Finder is done; its layout pass drops it otherwise.
  cp Resources/AppIcon.icns "$VOLUME/.VolumeIcon.icns"
  SetFile -a C "$VOLUME"
  sync
  hdiutil detach -quiet "$DEVICE"
  hdiutil convert -quiet "$RW" -format UDZO -imagekey zlib-level=9 -o build/Cloister.dmg
  rm -rf "$STAGE" "$RW"
  echo "Packaged build/Cloister.dmg"
fi
