#!/usr/bin/env bash
# Regenerate every macOS AppIcon size from sluice-icon-master.png.
# Run from anywhere; paths are resolved against this script.

set -euo pipefail
HERE="$(cd "$(dirname "$0")" && pwd)"
MASTER="$HERE/sluice-icon-master.png"
ICONSET="$HERE/../../Sluice/App/Assets.xcassets/AppIcon.appiconset"

cp "$MASTER" "$ICONSET/icon_512x512@2x.png"
for spec in "16:icon_16x16" "32:icon_16x16@2x" "32:icon_32x32" "64:icon_32x32@2x" \
            "128:icon_128x128" "256:icon_128x128@2x" "256:icon_256x256" \
            "512:icon_256x256@2x" "512:icon_512x512"; do
  sz="${spec%%:*}"
  name="${spec##*:}"
  sips -z "$sz" "$sz" "$MASTER" --out "$ICONSET/$name.png" > /dev/null
done
echo "regenerated 10 PNG sizes into $ICONSET"
