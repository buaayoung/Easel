#!/usr/bin/env bash
# Copy dist/sidecar into the Flutter macOS Runner Resources folder.
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
SRC="${EASEL_VENDOR_ROOT:-$ROOT/dist/sidecar}"
DEST="$ROOT/flutter/macos/Runner/Resources/sidecar"

if [[ ! -d "$SRC" ]]; then
  echo "Missing sidecar at $SRC — run scripts/bundle_sidecar.sh first" >&2
  exit 1
fi

mkdir -p "$(dirname "$DEST")"
rm -rf "$DEST"
# Prefer rsync; fall back to cp
if command -v rsync >/dev/null; then
  rsync -a "$SRC/" "$DEST/"
else
  mkdir -p "$DEST"
  cp -R "$SRC"/. "$DEST/"
fi

# Ensure Xcode copies Resources: Flutter macOS template uses Runner/Resources
# if present via the Copy Bundle Resources phase for Info.plist assets.
# Also write a marker for the Dart resolver.
echo "{\"embedded\":true,\"source\":\"$SRC\"}" > "$DEST/.embedded.json"
echo "Embedded sidecar → $DEST"
du -sh "$DEST"
