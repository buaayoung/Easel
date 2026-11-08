#!/usr/bin/env bash
# Full macOS package: vendor sidecar → flutter build → embed into .app → DMG.
# Env:
#   PACKAGE_MODE=full|host  — full=内置可重定位 Python/依赖（默认）；
#                             host=仅打源码，运行时用宿主机环境，缺依赖时首次启动安装
#   SKIP_DOWNLOAD=1         — bundle_sidecar 不拉远程二进制（仅 full）
#   SKIP_BUNDLE=1           — 跳过 sidecar 组装，复用已有 OUT
#   SKIP_FLUTTER_BUILD=1    — 跳过 flutter build，复用已有 Release .app
#   OUT=...                 — sidecar 输出目录
#   DMG_PATH=...            — DMG 输出路径
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
FLUTTER_BIN="${FLUTTER_BIN:-$(command -v flutter || true)}"
if [[ -z "${FLUTTER_BIN}" ]]; then
  echo "flutter not found in PATH; set FLUTTER_BIN" >&2
  exit 1
fi

PACKAGE_MODE="${PACKAGE_MODE:-full}"
case "$PACKAGE_MODE" in
  full|host) ;;
  *) echo "PACKAGE_MODE must be full or host (got: $PACKAGE_MODE)" >&2; exit 1 ;;
esac

VERSION="$(
  python3 - "$ROOT/flutter/pubspec.yaml" <<'PY' 2>/dev/null || true
import re, pathlib, sys
text = pathlib.Path(sys.argv[1]).read_text(encoding="utf-8")
m = re.search(r"^version:\s*([^\s+#]+)", text, re.M)
print(m.group(1) if m else "1.0.0")
PY
)"
VERSION="${VERSION:-1.0.0}"
VERSION="${VERSION%%+*}"

if [[ -z "${OUT:-}" ]]; then
  if [[ "$PACKAGE_MODE" == "host" ]]; then
    OUT="$ROOT/dist/sidecar-host"
  else
    OUT="$ROOT/dist/sidecar"
  fi
fi
if [[ -z "${DMG_PATH:-}" ]]; then
  if [[ "$PACKAGE_MODE" == "host" ]]; then
    DMG_PATH="$ROOT/dist/Unisyn-${VERSION}-macos-host.dmg"
  else
    DMG_PATH="$ROOT/dist/Unisyn-${VERSION}-macos.dmg"
  fi
fi

echo "==> PACKAGE_MODE=$PACKAGE_MODE"
echo "    OUT=$OUT"
echo "    DMG_PATH=$DMG_PATH"

if [[ "${SKIP_BUNDLE:-0}" != "1" ]]; then
  if [[ "$PACKAGE_MODE" == "host" ]]; then
    OUT="$OUT" "$ROOT/scripts/bundle_sidecar_host.sh"
  else
    SKIP_DOWNLOAD="${SKIP_DOWNLOAD:-0}" OUT="$OUT" \
      "$ROOT/scripts/bundle_sidecar.sh"
  fi
else
  if [[ ! -d "$OUT" ]]; then
    echo "SKIP_BUNDLE=1 but sidecar missing at $OUT" >&2
    exit 1
  fi
  echo "Skipping sidecar bundle (reuse $OUT)"
fi

cd "$ROOT/flutter"
if [[ "${SKIP_FLUTTER_BUILD:-0}" != "1" ]]; then
  "$FLUTTER_BIN" pub get
  "$FLUTTER_BIN" build macos --release
else
  echo "Skipping flutter build (reuse existing Release .app)"
fi

APP="$ROOT/flutter/build/macos/Build/Products/Release/Unisyn.app"
if [[ ! -d "$APP" ]]; then
  APP="$(find "$ROOT/flutter/build/macos" -name 'Unisyn.app' -type d | head -1 || true)"
fi
if [[ -z "${APP:-}" || ! -d "$APP" ]]; then
  echo "Could not locate Unisyn.app under flutter/build/macos" >&2
  exit 1
fi

DEST="$APP/Contents/Resources/sidecar"
rm -rf "$DEST"
mkdir -p "$(dirname "$DEST")"
rsync -a "$OUT/" "$DEST/"
echo "Packaged → $APP (mode=$PACKAGE_MODE)"
du -sh "$APP" "$DEST"

# ---- DMG ----
STAGE="$(mktemp -d "${TMPDIR:-/tmp}/unisyn-dmg.XXXXXX")"
cleanup() { rm -rf "$STAGE"; }
trap cleanup EXIT

cp -R "$APP" "$STAGE/Unisyn.app"
ln -s /Applications "$STAGE/Applications"

mkdir -p "$(dirname "$DMG_PATH")"
rm -f "$DMG_PATH"
hdiutil create \
  -volname "Unisyn" \
  -srcfolder "$STAGE" \
  -ov \
  -format UDZO \
  "$DMG_PATH"

echo "DMG → $DMG_PATH"
ls -lh "$DMG_PATH"
