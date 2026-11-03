# Sidecar vendor bundle

`scripts/bundle_sidecar.sh` builds `dist/sidecar/` for the Flutter host.

| Path | Role |
|------|------|
| `python/` | venv with easel (`--no-deps`) + wheel-friendly runtime deps; `biliup`/`rembg` optional (sdists often hang) |
| `node/` | Node 24.x |
| `openclaw/` | private `npm install --prefix` tree |
| `ffmpeg/bin/` | ffmpeg / ffprobe |
| `remotion-blueprint/` | Remotion deps with `node_modules` |
| `web/` | FastAPI app (+ `frontend/dist` if built) |
| `easel-root/` | skills / agents / profiles / easel package snapshot |

Whisper large-v3 (~3GB) is **not** bundled. Set `EASEL_MODELS_DIR` to Application Support and install via `POST /api/env/install` with `id=model`.

## Environment

```bash
export EASEL_VENDOR_ROOT=…/dist/sidecar
export EASEL_ROOT=…/dist/sidecar/easel-root
export EASEL_PACKAGED=1
export EASEL_MODELS_DIR="$HOME/Library/Application Support/Easel/models"
export EASEL_OPENCLAW_STATE_DIR="$HOME/Library/Application Support/Easel/openclaw-state"
export EASEL_DATA_DIR="$HOME/Library/Application Support/Easel"
export EASEL_PORT=17860
```

Flutter sets these before spawning `"$EASEL_VENDOR_ROOT/python/bin/python" "$EASEL_VENDOR_ROOT/web/app.py"`.
