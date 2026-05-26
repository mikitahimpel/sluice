#!/usr/bin/env bash
# Build, sign, notarize, and staple a release of Sluice.
#
# Prerequisites (one-time):
#   1. Developer ID Application cert in the login keychain.
#      Generate via Xcode > Settings > Accounts > Manage Certificates > + > Developer ID Application.
#   2. Notarization credentials stored under the profile name "Sluice-Notarization":
#         xcrun notarytool store-credentials "Sluice-Notarization" \
#             --apple-id "<your-apple-id>" \
#             --team-id "2666YPBJTB" \
#             --password "<app-specific-password>"
#
# Usage: scripts/release.sh <version>   e.g. scripts/release.sh 0.1.0

set -euo pipefail

VERSION="${1:?Usage: $0 <version>}"
TEAM_ID="2666YPBJTB"
SIGNING_IDENTITY="Developer ID Application: Mikita Himpel (${TEAM_ID})"
NOTARY_PROFILE="Sluice-Notarization"
PROJECT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
BUILD_DIR="$PROJECT_DIR/build/release"
RELEASE_DIR="$PROJECT_DIR/release-artifacts"
APP_BUNDLE="$BUILD_DIR/Build/Products/Release/Sluice.app"
ZIP_PATH="$RELEASE_DIR/Sluice-${VERSION}.zip"

cd "$PROJECT_DIR"

echo "==> Cleaning build directory"
rm -rf "$BUILD_DIR" "$RELEASE_DIR"
mkdir -p "$RELEASE_DIR"

echo "==> Verifying signing identity is available"
if ! security find-identity -v -p codesigning | grep -q "$SIGNING_IDENTITY"; then
  echo "ERROR: signing identity not found: $SIGNING_IDENTITY"
  echo "Generate it: Xcode > Settings > Accounts > Manage Certificates > + > Developer ID Application"
  exit 1
fi

echo "==> Building Release configuration"
xcodebuild \
  -project Sluice.xcodeproj \
  -scheme Sluice \
  -configuration Release \
  -derivedDataPath "$BUILD_DIR" \
  CODE_SIGN_STYLE=Manual \
  CODE_SIGN_IDENTITY="$SIGNING_IDENTITY" \
  DEVELOPMENT_TEAM="$TEAM_ID" \
  CODE_SIGN_INJECT_BASE_ENTITLEMENTS=NO \
  OTHER_CODE_SIGN_FLAGS="--timestamp --options runtime" \
  build \
  -quiet

echo "==> Verifying signature"
codesign --verify --deep --strict --verbose=2 "$APP_BUNDLE"
spctl --assess --type execute --verbose "$APP_BUNDLE" || true

echo "==> Zipping for notarization"
ditto -c -k --keepParent "$APP_BUNDLE" "$ZIP_PATH"

echo "==> Submitting to Apple notary service (this takes 2-10 minutes)"
xcrun notarytool submit "$ZIP_PATH" \
  --keychain-profile "$NOTARY_PROFILE" \
  --wait

echo "==> Stapling notarization ticket to the .app"
xcrun stapler staple "$APP_BUNDLE"
xcrun stapler validate "$APP_BUNDLE"

echo "==> Re-zipping with stapled ticket"
rm "$ZIP_PATH"
ditto -c -k --keepParent "$APP_BUNDLE" "$ZIP_PATH"

SIZE_HUMAN="$(du -h "$ZIP_PATH" | cut -f1)"
SHA256="$(shasum -a 256 "$ZIP_PATH" | cut -d' ' -f1)"

echo ""
echo "==> Release artifact ready:"
echo "    Path:   $ZIP_PATH"
echo "    Size:   $SIZE_HUMAN"
echo "    SHA256: $SHA256"
