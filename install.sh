#!/usr/bin/env bash
# Install Sluice — macOS URL router.
#
# Usage:
#   curl -fsSL https://raw.githubusercontent.com/mikitahimpel/sluice/main/install.sh | bash
#
# What this does:
#   1. Downloads the latest notarized release zip from GitHub
#   2. Unzips it to /Applications/Sluice.app (or ~/Applications if /Applications isn't writable)
#   3. Registers it with Launch Services so it's recognized as a URL handler
#   4. Launches the app so it appears in your menu bar
#
# Uninstall: drag /Applications/Sluice.app to the Trash; remove
#   ~/Library/Application\ Support/Sluice to wipe rules.

set -euo pipefail

REPO="mikitahimpel/sluice"
APP_NAME="Sluice.app"

if [[ "$(uname -s)" != "Darwin" ]]; then
  echo "Sluice is a macOS app — won't run on $(uname -s)." >&2
  exit 1
fi

echo "==> Looking up latest Sluice release"
LATEST_URL="$(curl -fsSL "https://api.github.com/repos/${REPO}/releases/latest" \
  | grep '"browser_download_url"' \
  | grep '\.zip"' \
  | head -1 \
  | cut -d'"' -f4)"

if [[ -z "${LATEST_URL}" ]]; then
  echo "Could not find a release zip on GitHub. Check https://github.com/${REPO}/releases" >&2
  exit 1
fi

VERSION="$(echo "$LATEST_URL" | sed -E 's|.*/v?([^/]+)/Sluice-[^/]+\.zip$|\1|')"
echo "    Found: ${VERSION}"

TMP_DIR="$(mktemp -d)"
trap 'rm -rf "$TMP_DIR"' EXIT

ZIP_PATH="$TMP_DIR/sluice.zip"
echo "==> Downloading"
curl -fsSL "$LATEST_URL" -o "$ZIP_PATH"

echo "==> Unzipping"
ditto -xk "$ZIP_PATH" "$TMP_DIR"

SRC_APP="$TMP_DIR/$APP_NAME"
if [[ ! -d "$SRC_APP" ]]; then
  echo "Downloaded archive didn't contain $APP_NAME — aborting." >&2
  exit 1
fi

if [[ -w /Applications ]]; then
  DEST_DIR="/Applications"
else
  DEST_DIR="$HOME/Applications"
  mkdir -p "$DEST_DIR"
fi
DEST_APP="$DEST_DIR/$APP_NAME"

if [[ -d "$DEST_APP" ]]; then
  echo "==> Removing existing $DEST_APP"
  rm -rf "$DEST_APP"
fi

echo "==> Installing to $DEST_APP"
ditto "$SRC_APP" "$DEST_APP"
xattr -dr com.apple.quarantine "$DEST_APP" 2>/dev/null || true

echo "==> Registering with Launch Services"
/System/Library/Frameworks/CoreServices.framework/Versions/Current/Frameworks/LaunchServices.framework/Versions/Current/Support/lsregister \
  -f "$DEST_APP" 2>/dev/null || true

echo "==> Launching Sluice"
open "$DEST_APP"

echo ""
echo "Sluice ${VERSION} installed."
echo "Next: System Settings → Default web browser → Sluice"
echo "Then add routing rules from the menu bar icon."
