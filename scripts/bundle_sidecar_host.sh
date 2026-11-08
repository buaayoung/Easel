#!/usr/bin/env bash
# Lite sidecar for PACKAGE_MODE=host DMG: ship source only, no relocatable Python/Node/ffmpeg.
# Runtime uses the host toolchain; first launch bootstraps Application Support venv.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
OUT="${OUT:-$ROOT/dist/sidecar-host}"
REMOTION_SRC="$ROOT/skills/builtin/video-production/vendor/video-pipeline-sdk/deps/remotion"

log() { printf '==> %s\n' "$*"; }

rm -rf "$OUT"
mkdir -p "$OUT"/{web,easel-root,remotion-blueprint}

log "Copy web/"
rsync -a --delete \
  --exclude '__pycache__' --exclude '*.pyc' --exclude '.venv' \
  --exclude 'frontend/node_modules' --exclude 'frontend/src' \
  "$ROOT/web/" "$OUT/web/"
if [[ -d "$ROOT/web/frontend/dist" ]]; then
  mkdir -p "$OUT/web/frontend"
  rsync -a "$ROOT/web/frontend/dist/" "$OUT/web/frontend/dist/"
fi

log "Copy easel-root/"
for part in easel skills agents profiles scripts; do
  if [[ -e "$ROOT/$part" ]]; then
    rsync -a --delete \
      --exclude '__pycache__' --exclude '*.pyc' --exclude 'node_modules' \
      --exclude '.git' --exclude 'outputs' --exclude '.remotion' \
      "$ROOT/$part" "$OUT/easel-root/"
  fi
done
cp "$ROOT/pyproject.toml" "$OUT/easel-root/" 2>/dev/null || true
[[ -f "$ROOT/README.md" ]] && cp "$ROOT/README.md" "$OUT/easel-root/" || true

log "Remotion blueprint (no node_modules — install on first use)"
if [[ -f "$REMOTION_SRC/package.json" ]]; then
  rsync -a --delete --exclude node_modules --exclude '.remotion' \
    "$REMOTION_SRC/" "$OUT/remotion-blueprint/"
else
  echo "WARN: remotion blueprint missing at $REMOTION_SRC" >&2
fi

# Marker consumed by Flutter path resolver / launcher.
cat > "$OUT/MANIFEST.json" <<EOF
{
  "createdAt": "$(date -u +%Y-%m-%dT%H:%M:%SZ)",
  "runtime": "host",
  "whisperBundled": false,
  "layout": ["web", "easel-root", "remotion-blueprint"]
}
EOF
echo "host" > "$OUT/.runtime-host"

log "Done (host runtime) → $OUT"
du -sh "$OUT" "$OUT"/* 2>/dev/null || true
