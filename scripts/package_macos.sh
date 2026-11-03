#!/usr/bin/env bash
# Full macOS package: vendor sidecar → flutter build → embed into .app Resources.
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
FLUTTER_BIN="${FLUTTER_BIN:-$(command -v flutter || true)}"
FLUTTER_BIN="${FLUTTER_BIN:-/Users/young-mini/developments/flutter/bin/flutter}"

SKIP_DOWNLOAD="${SKIP_DOWNLOAD:-0}" OUT="${OUT:-$ROOT/dist/sidecar}" \
  "$ROOT/scripts/bundle_sidecar.sh"

cd "$ROOT/flutter"
"$FLUTTER_BIN" pub get
"$FLUTTER_BIN" build macos --release

APP="$ROOT/flutter/build/macos/Build/Products/Release/easel_app.app"
if [[ ! -d "$APP" ]]; then
  # Flutter 3.16+ may use a slightly different product path
  APP="$(find "$ROOT/flutter/build/macos" -name 'easel_app.app' -type d | head -1 || true)"
fi
if [[ -z "${APP:-}" || ! -d "$APP" ]]; then
  echo "Could not locate easel_app.app under flutter/build/macos" >&2
  exit 1
fi

DEST="$APP/Contents/Resources/sidecar"
rm -rf "$DEST"
mkdir -p "$(dirname "$DEST")"
rsync -a "$ROOT/dist/sidecar/" "$DEST/"
echo "Packaged → $APP"
du -sh "$APP" "$DEST"
