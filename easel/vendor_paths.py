"""App-bundle / sidecar vendor path helpers.

When Flutter (or a packaging script) sets ``EASEL_VENDOR_ROOT``, runtimes prefer
binaries under that tree over system PATH installs. Large model weights stay
outside the bundle under ``EASEL_MODELS_DIR`` (default ``~/models``).
"""

from __future__ import annotations

import os
from pathlib import Path

WINDOWS = os.name == "nt"

# Canonical on-disk name for the faster-whisper large-v3 snapshot (install_tool /
# fetch_whisper_model / asr consumers agree on this under EASEL_MODELS_DIR).
WHISPER_LARGE_V3_DIRNAME = "whisper-large-v3"


def vendor_root(environment: dict[str, str] | None = None) -> Path | None:
    env = environment if environment is not None else os.environ
    raw = (env.get("EASEL_VENDOR_ROOT") or "").strip()
    if not raw:
        return None
    path = Path(raw).expanduser()
    try:
        return path.resolve()
    except OSError:
        return path


def models_dir(environment: dict[str, str] | None = None) -> Path:
    env = environment if environment is not None else os.environ
    raw = (env.get("EASEL_MODELS_DIR") or "").strip()
    if raw:
        path = Path(raw).expanduser()
    else:
        path = Path.home() / "models"
    try:
        return path.resolve()
    except OSError:
        return path


def whisper_large_v3_dir(environment: dict[str, str] | None = None) -> Path:
    return models_dir(environment) / WHISPER_LARGE_V3_DIRNAME


def is_packaged(environment: dict[str, str] | None = None) -> bool:
    """True when running inside a Flutter/app-bundle sidecar."""
    env = environment if environment is not None else os.environ
    flag = (env.get("EASEL_PACKAGED") or "").strip().lower()
    if flag in ("1", "true", "yes", "on"):
        return True
    return vendor_root(env) is not None


def vendor_bin_dirs(root: Path | None = None) -> list[Path]:
    """Ordered PATH prefixes under a vendor root (existing dirs only)."""
    base = root if root is not None else vendor_root()
    if base is None:
        return []
    candidates = [
        base / "ffmpeg" / "bin",
        base / "bin",
        base / "node" / "bin",
        base / "node",  # Windows zip often puts node.exe at the root
        base / "openclaw" / "bin",
        base / "python" / "bin",
        base / "python" / "Scripts",  # Windows embeddable / venv
        base / "python",
    ]
    out: list[Path] = []
    seen: set[str] = set()
    for directory in candidates:
        try:
            if not directory.is_dir():
                continue
        except OSError:
            continue
        key = os.path.normcase(str(directory))
        if key in seen:
            continue
        seen.add(key)
        out.append(directory)
    return out


def vendor_node(root: Path | None = None) -> Path | None:
    base = root if root is not None else vendor_root()
    if base is None:
        return None
    names = ("node.exe", "node") if WINDOWS else ("node",)
    for directory in (
        base / "node" / "bin",
        base / "node",
        base / "bin",
    ):
        for name in names:
            cand = directory / name
            try:
                if cand.is_file() and (WINDOWS or os.access(cand, os.X_OK)):
                    return cand
            except OSError:
                continue
    return None


def vendor_openclaw_mjs(root: Path | None = None) -> Path | None:
    base = root if root is not None else vendor_root()
    if base is None:
        return None
    candidates = [
        base / "openclaw" / "openclaw.mjs",
        base / "openclaw" / "node_modules" / "openclaw" / "openclaw.mjs",
        base / "openclaw" / "lib" / "node_modules" / "openclaw" / "openclaw.mjs",
        base / "node" / "lib" / "node_modules" / "openclaw" / "openclaw.mjs",
        base / "node" / "node_modules" / "openclaw" / "openclaw.mjs",
    ]
    for cand in candidates:
        try:
            if cand.is_file():
                return cand
        except OSError:
            continue
    return None


def vendor_python(root: Path | None = None) -> Path | None:
    base = root if root is not None else vendor_root()
    if base is None:
        return None
    names = ("python.exe", "python") if WINDOWS else ("python3", "python")
    for directory in (
        base / "python" / "bin",
        base / "python" / "Scripts",
        base / "python",
    ):
        for name in names:
            cand = directory / name
            try:
                if cand.is_file() and (WINDOWS or os.access(cand, os.X_OK)):
                    return cand
            except OSError:
                continue
    return None


def remotion_blueprint_dir(root: Path | None = None) -> Path | None:
    base = root if root is not None else vendor_root()
    if base is None:
        return None
    for cand in (
        base / "remotion-blueprint",
        base / "remotion",
    ):
        try:
            if (cand / "package.json").is_file():
                return cand
        except OSError:
            continue
    return None


# Tools that must not be installed system-wide when packaged; they are expected
# to already live under EASEL_VENDOR_ROOT.
PACKAGED_BUILTIN_TOOL_IDS = frozenset({
    "node", "ffmpeg", "python", "fw", "pylibs",
})

# Allowed on-demand installs even in packaged mode (large assets / writable dirs).
PACKAGED_ON_DEMAND_TOOL_IDS = frozenset({
    "model", "rmdeps", "shell", "pw", "cft", "biliup",
})
