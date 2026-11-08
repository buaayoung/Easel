#!/usr/bin/env bash
# Create / refresh the project uv venv at <repo>/.venv for flutter run / CLI.
# Same CPython series as bundle_sidecar.sh so packaging can reuse the uv cache.
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
PYTHON_VERSION="${EASEL_BUNDLE_PYTHON_VERSION:-3.13.9}"
PIP_INDEX="${EASEL_PIP_INDEX:-https://pypi.tuna.tsinghua.edu.cn/simple}"

need() { command -v "$1" >/dev/null 2>&1 || { echo "missing: $1" >&2; exit 1; }; }
need uv

cd "$ROOT"
echo "==> uv python $PYTHON_VERSION (cached if already installed)"
uv python install "$PYTHON_VERSION"

if [[ ! -x "$ROOT/.venv/bin/python" && ! -x "$ROOT/.venv/Scripts/python.exe" ]]; then
  echo "==> uv venv .venv"
  uv venv --python "$PYTHON_VERSION" "$ROOT/.venv"
else
  echo "==> reuse existing .venv"
fi

VENV_PY="$ROOT/.venv/bin/python"
[[ -x "$VENV_PY" ]] || VENV_PY="$ROOT/.venv/Scripts/python.exe"

# Settings panel / install_tool use `python -m pip`; uv venvs omit pip by default.
echo "==> ensure pip in .venv"
uv pip install --python "$VENV_PY" pip -i "$PIP_INDEX" >/dev/null
"$VENV_PY" -m pip --version >/dev/null

echo "==> install project + runtime deps into .venv"
uv pip install --python "$VENV_PY" -e "$ROOT" -i "$PIP_INDEX"
# Match sidecar optionals when possible (non-fatal).
uv pip install --python "$VENV_PY" 'rembg>=2.0,<3' -i "$PIP_INDEX" || \
  echo "WARN: rembg skipped" >&2

"$VENV_PY" - <<'PY'
import fastapi, easel, sys
print("dev venv ok:", sys.executable)
print("fastapi:", fastapi.__version__)
print("easel:", easel.__file__)
PY

echo
echo "Flutter debug will use: $VENV_PY"
echo "Next: cd flutter && flutter run -d macos"
