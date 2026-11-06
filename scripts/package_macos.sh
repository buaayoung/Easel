#!/usr/bin/env bash
# Full macOS package: vendor sidecar → flutter build → embed into .app → DMG.
# Env:
#   SKIP_DOWNLOAD=1     — bundle_sidecar 不拉远程二进制（链系统 node/ffmpeg）
#   SKIP_BUNDLE=1       — 跳过 sidecar 组装，复用 dist/sidecar
#   SKIP_FLUTTER_BUILD=1 — 跳过 flutter build，复用已有 Release .app
#   OUT=...             — sidecar 输出目录（默认 dist/sidecar）
#   DMG_PATH=...        — DMG 输出路径（默认 dist/Easel-<version>-macos.dmg）
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
FLUTTER_BIN="${FLUTTER_BIN:-$(command -v flutter || true)}"
if [[ -z "${FLUTTER_BIN}" ]]; then
  echo "flutter not found in PATH; set FLUTTER_BIN" >&2
  exit 1
fi

VERSION="$(
  python3 - "$ROOT/flutter/pubspec.yaml" <<'PY' 2>/dev/null || true
import re, pathlib, sys
text = pathlib.Path(sys.argv[1]).read_text(encoding="utf-8")
m = re.search(r"^version:\s*([^\s+#]+)", text, re.M)
print(m.group(1) if m else "1.0.0")
PY
)"
VERSION="${VERSION:-1.0.0}"
# 去掉 pubspec build 号（1.0.0+1 → 1.0.0），避免文件名里的 +
VERSION="${VERSION%%+*}"
DMG_PATH="${DMG_PATH:-$ROOT/dist/Easel-${VERSION}-macos.dmg}"

if [[ "${SKIP_BUNDLE:-0}" != "1" ]]; then
  SKIP_DOWNLOAD="${SKIP_DOWNLOAD:-0}" OUT="${OUT:-$ROOT/dist/sidecar}" \
    "$ROOT/scripts/bundle_sidecar.sh"
else
  if [[ ! -d "${OUT:-$ROOT/dist/sidecar}" ]]; then
    echo "SKIP_BUNDLE=1 but sidecar missing at ${OUT:-$ROOT/dist/sidecar}" >&2
    exit 1
  fi
  echo "Skipping sidecar bundle (reuse ${OUT:-$ROOT/dist/sidecar})"
fi

cd "$ROOT/flutter"
if [[ "${SKIP_FLUTTER_BUILD:-0}" != "1" ]]; then
  "$FLUTTER_BIN" pub get
  "$FLUTTER_BIN" build macos --release
else
  echo "Skipping flutter build (reuse existing Release .app)"
fi

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

# ---- DMG ----
STAGE="$(mktemp -d "${TMPDIR:-/tmp}/easel-dmg.XXXXXX")"
cleanup() { rm -rf "$STAGE"; }
trap cleanup EXIT

# Finder 里更友好的名字；可拖到 Applications
cp -R "$APP" "$STAGE/Easel.app"
ln -s /Applications "$STAGE/Applications"

mkdir -p "$(dirname "$DMG_PATH")"
rm -f "$DMG_PATH"
hdiutil create \
  -volname "Easel" \
  -srcfolder "$STAGE" \
  -ov \
  -format UDZO \
  "$DMG_PATH"

echo "DMG → $DMG_PATH"
ls -lh "$DMG_PATH"
