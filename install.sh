#!/bin/bash
# Installs the latest Cloister release into /Applications.
#
#   curl -fsSL https://raw.githubusercontent.com/ArfiArfath21/cloister/main/install.sh | bash
#
# Set INSTALL_DIR to install somewhere else.
set -euo pipefail

URL="https://github.com/ArfiArfath21/cloister/releases/latest/download/Cloister.dmg"
DEST="${INSTALL_DIR:-/Applications}"

if [ "$(uname -s)" != "Darwin" ]; then
  echo "Cloister runs on macOS only." >&2
  exit 1
fi

# Fall back to ~/Applications when /Applications isn't writable (non-admin users).
if [ ! -w "$DEST" ]; then
  DEST="$HOME/Applications"
  mkdir -p "$DEST"
fi

WORK=$(mktemp -d)
MOUNT="$WORK/mount"
cleanup() {
  hdiutil detach -quiet "$MOUNT" 2>/dev/null || true
  rm -rf "$WORK"
}
trap cleanup EXIT

echo "Downloading Cloister…"
curl -fsSL "$URL" -o "$WORK/Cloister.dmg"

mkdir -p "$MOUNT"
hdiutil attach -quiet -nobrowse -noautoopen -mountpoint "$MOUNT" "$WORK/Cloister.dmg"

# Quit a running copy (it refuses to quit mid-session, which is fine).
osascript -e 'tell application id "com.arfiarfath21.cloister" to quit' >/dev/null 2>&1 || true

echo "Installing to $DEST…"
rm -rf "$DEST/Cloister.app"
ditto "$MOUNT/Cloister.app" "$DEST/Cloister.app"
# curl doesn't mark downloads as quarantined, but clear it in case anything did.
find "$DEST/Cloister.app" -exec xattr -d com.apple.quarantine {} + 2>/dev/null || true

echo "Installed Cloister to $DEST/Cloister.app"
if [ -z "${INSTALL_DIR:-}" ]; then
  open "$DEST/Cloister.app"
fi
