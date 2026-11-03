#!/usr/bin/env bash
# Assemble a local FastAPI sidecar vendor tree for the Flutter desktop host.
#
# Layout written to $OUT (default: dist/sidecar):
#   python/   node/   openclaw/   ffmpeg/bin/   remotion-blueprint/   web/   easel-root/
#
# Large Whisper weights are NEVER copied here — download at runtime into
# EASEL_MODELS_DIR (Application Support).
#
# Usage:
#   ./scripts/bundle_sidecar.sh
#   OUT=/tmp/easel-sidecar SKIP_DOWNLOAD=1 ./scripts/bundle_sidecar.sh   # link local tools only
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
OUT="${OUT:-$ROOT/dist/sidecar}"
NODE_VERSION="${NODE_VERSION:-24.16.0}"
SKIP_DOWNLOAD="${SKIP_DOWNLOAD:-0}"
NPM_REGISTRY="${EASEL_NPM_REGISTRY:-https://registry.npmmirror.com}"
REMOTION_SRC="$ROOT/skills/builtin/video-production/vendor/video-pipeline-sdk/deps/remotion"

uname_s="$(uname -s)"
uname_m="$(uname -m)"
case "$uname_s-$uname_m" in
  Darwin-arm64)  NODE_PLATFORM=darwin-arm64; FFMPEG_HINT=macos-arm64 ;;
  Darwin-x86_64) NODE_PLATFORM=darwin-x64;   FFMPEG_HINT=macos-x64 ;;
  Linux-x86_64)  NODE_PLATFORM=linux-x64;    FFMPEG_HINT=linux-x64 ;;
  Linux-aarch64) NODE_PLATFORM=linux-arm64;  FFMPEG_HINT=linux-arm64 ;;
  *) echo "Unsupported platform: $uname_s $uname_m" >&2; exit 1 ;;
esac

log() { printf '==> %s\n' "$*"; }
need() { command -v "$1" >/dev/null 2>&1 || { echo "missing: $1" >&2; exit 1; }; }

need python3
need curl
need tar

rm -rf "$OUT"
mkdir -p "$OUT"/{python,node,openclaw,ffmpeg/bin,remotion-blueprint,web,easel-root}

# ── Python: venv with project + FastAPI stack (no Whisper weights) ──────────
# Do NOT `pip install -e .` with full pyproject deps: biliup (and similar) ship
# sdists only and routinely hang on "Preparing metadata (pyproject.toml)".
# Install the easel package with --no-deps, then a curated wheel-friendly set.
log "Python vendor venv"
PIP_INDEX="${EASEL_PIP_INDEX:-https://pypi.tuna.tsinghua.edu.cn/simple}"
python3 -m venv "$OUT/python"
# shellcheck disable=SC1091
source "$OUT/python/bin/activate"
pip install -U pip wheel setuptools >/dev/null
pip install -e "$ROOT" --no-deps -i "$PIP_INDEX"
pip install \
  'fastapi>=0.115,<1' 'uvicorn[standard]>=0.30,<1' 'sse-starlette>=2.1,<4' \
  'httpx>=0.27,<1' 'pydantic>=2.7,<3' 'segno>=1.6,<2' 'python-multipart>=0.0.9,<1' \
  'Pillow>=10,<13' 'opencv-python>=4.8,<5' 'numpy>=1.26,<3' \
  'PyMuPDF>=1.26.7,<2' 'pandas>=2,<4' 'matplotlib>=3.8,<4' 'librosa>=0.10,<1' \
  'faster-whisper>=1,<2' 'huggingface_hub' 'edge-tts>=6,<8' 'playwright>=1.45,<2' \
  'jieba>=0.42,<1' 'snownlp>=0.12,<1' 'markdown>=3.5,<4' \
  'requests>=2.32,<3' 'beautifulsoup4>=4.12,<5' \
  'websocket-client>=1.7,<2' 'cryptography>=42' \
  -i "$PIP_INDEX"
# Optional / sdist-heavy: skip on failure so the sidecar still builds.
for opt in 'rembg>=2.0,<3' 'biliup>=1,<2'; do
  log "Optional pip: $opt"
  if ! pip install "$opt" -i "$PIP_INDEX"; then
    echo "WARN: skipped $opt (sidecar core still usable)" >&2
  fi
done
deactivate

# ── Node ────────────────────────────────────────────────────────────────────
NODE_TGZ="node-v${NODE_VERSION}-${NODE_PLATFORM}.tar.gz"
NODE_URL="${EASEL_NODE_MIRROR:-https://npmmirror.com/mirrors/node}/v${NODE_VERSION}/${NODE_TGZ}"
if [[ "$SKIP_DOWNLOAD" == "1" ]] && command -v node >/dev/null; then
  log "SKIP_DOWNLOAD=1 · symlink system node"
  ln -sfn "$(dirname "$(dirname "$(command -v node)")")" "$OUT/node-link" || true
  # Prefer a real copy layout for PATH helpers
  mkdir -p "$OUT/node/bin"
  ln -sfn "$(command -v node)" "$OUT/node/bin/node"
  command -v npm >/dev/null && ln -sfn "$(command -v npm)" "$OUT/node/bin/npm"
  command -v npx >/dev/null && ln -sfn "$(command -v npx)" "$OUT/node/bin/npx"
else
  log "Download Node $NODE_VERSION ($NODE_PLATFORM)"
  curl -fsSL "$NODE_URL" -o "$OUT/$NODE_TGZ"
  tar -xzf "$OUT/$NODE_TGZ" -C "$OUT"
  rm -f "$OUT/$NODE_TGZ"
  mv "$OUT/node-v${NODE_VERSION}-${NODE_PLATFORM}"/* "$OUT/node/"
  rmdir "$OUT/node-v${NODE_VERSION}-${NODE_PLATFORM}"
fi
export PATH="$OUT/node/bin:$PATH"

# ── OpenClaw (private prefix, not global npm -g) ────────────────────────────
log "Install openclaw into vendor/openclaw"
mkdir -p "$OUT/openclaw"
npm install --prefix "$OUT/openclaw" openclaw@latest --registry="$NPM_REGISTRY"
# Flatten discovery paths used by easel.vendor_paths.vendor_openclaw_mjs
if [[ -f "$OUT/openclaw/node_modules/openclaw/openclaw.mjs" ]]; then
  ln -sfn node_modules/openclaw/openclaw.mjs "$OUT/openclaw/openclaw.mjs"
fi

# ── ffmpeg ──────────────────────────────────────────────────────────────────
if [[ "$SKIP_DOWNLOAD" == "1" ]] && command -v ffmpeg >/dev/null; then
  log "SKIP_DOWNLOAD=1 · symlink system ffmpeg ($FFMPEG_HINT)"
  ln -sfn "$(command -v ffmpeg)" "$OUT/ffmpeg/bin/ffmpeg"
  command -v ffprobe >/dev/null && ln -sfn "$(command -v ffprobe)" "$OUT/ffmpeg/bin/ffprobe"
else
  log "ffmpeg: place full-build binaries into $OUT/ffmpeg/bin (auto-download not wired for all OS)"
  if command -v ffmpeg >/dev/null; then
    cp "$(command -v ffmpeg)" "$OUT/ffmpeg/bin/ffmpeg"
    command -v ffprobe >/dev/null && cp "$(command -v ffprobe)" "$OUT/ffmpeg/bin/ffprobe"
  else
    echo "WARN: ffmpeg not on PATH; copy a full build into $OUT/ffmpeg/bin before shipping" >&2
  fi
fi

# ── Remotion blueprint (+ npm ci) ───────────────────────────────────────────
log "Remotion blueprint"
if [[ -f "$REMOTION_SRC/package.json" ]]; then
  rsync -a --delete --exclude node_modules "$REMOTION_SRC/" "$OUT/remotion-blueprint/"
  if [[ -f "$OUT/remotion-blueprint/package-lock.json" || -f "$OUT/remotion-blueprint/package.json" ]]; then
    (cd "$OUT/remotion-blueprint" && npm ci --registry="$NPM_REGISTRY" || npm install --registry="$NPM_REGISTRY")
  fi
else
  echo "WARN: remotion blueprint missing at $REMOTION_SRC" >&2
fi

# ── Web + easel-root snapshot ───────────────────────────────────────────────
log "Copy web/ and easel-root/"
rsync -a --delete \
  --exclude '__pycache__' --exclude '*.pyc' --exclude '.venv' \
  --exclude 'frontend/node_modules' --exclude 'frontend/src' \
  "$ROOT/web/" "$OUT/web/"
# Prefer built SPA if present
if [[ -d "$ROOT/web/frontend/dist" ]]; then
  mkdir -p "$OUT/web/frontend"
  rsync -a "$ROOT/web/frontend/dist/" "$OUT/web/frontend/dist/"
fi

for part in easel skills agents profiles scripts; do
  if [[ -e "$ROOT/$part" ]]; then
    rsync -a --delete \
      --exclude '__pycache__' --exclude '*.pyc' --exclude 'node_modules' \
      --exclude '.git' --exclude 'outputs' \
      "$ROOT/$part" "$OUT/easel-root/"
  fi
done
# Minimal pyproject so editable installs / imports resolve
cp "$ROOT/pyproject.toml" "$OUT/easel-root/" 2>/dev/null || true
[[ -f "$ROOT/README.md" ]] && cp "$ROOT/README.md" "$OUT/easel-root/" || true

# Marker for Flutter / docs
cat > "$OUT/MANIFEST.json" <<EOF
{
  "createdAt": "$(date -u +%Y-%m-%dT%H:%M:%SZ)",
  "platform": "$NODE_PLATFORM",
  "nodeVersion": "$NODE_VERSION",
  "whisperBundled": false,
  "layout": ["python", "node", "openclaw", "ffmpeg", "remotion-blueprint", "web", "easel-root"]
}
EOF

log "Done → $OUT"
du -sh "$OUT"/* 2>/dev/null || true
echo
echo "Run sidecar with (EASEL_ROOT must point at easel-root so skills/ resolve):"
echo "  export EASEL_VENDOR_ROOT=\"$OUT\""
echo "  export EASEL_ROOT=\"$OUT/easel-root\""
echo "  export EASEL_PACKAGED=1"
echo "  export PATH=\"$OUT/ffmpeg/bin:$OUT/node/bin:\$PATH\""
echo "  \"$OUT/python/bin/python\" \"$OUT/web/app.py\""
