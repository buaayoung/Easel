"""EASEL_VENDOR_ROOT / EASEL_MODELS_DIR path helpers."""
from __future__ import annotations

import os
from pathlib import Path

import pytest

from easel import openclaw_cmd as oc
from easel import runtime_env
from easel import vendor_paths as vp


def test_models_dir_default(monkeypatch, tmp_path):
    monkeypatch.delenv("EASEL_MODELS_DIR", raising=False)
    monkeypatch.setattr(Path, "home", staticmethod(lambda: tmp_path))
    assert vp.models_dir() == (tmp_path / "models").resolve()
    assert vp.whisper_large_v3_dir() == (tmp_path / "models" / "whisper-large-v3").resolve()


def test_models_dir_override(monkeypatch, tmp_path):
    target = tmp_path / "data" / "models"
    monkeypatch.setenv("EASEL_MODELS_DIR", str(target))
    assert vp.whisper_large_v3_dir() == (target / "whisper-large-v3").resolve()


def test_is_packaged_from_flag_or_vendor(monkeypatch, tmp_path):
    monkeypatch.delenv("EASEL_PACKAGED", raising=False)
    monkeypatch.delenv("EASEL_VENDOR_ROOT", raising=False)
    assert vp.is_packaged() is False
    monkeypatch.setenv("EASEL_PACKAGED", "1")
    assert vp.is_packaged() is True
    monkeypatch.delenv("EASEL_PACKAGED", raising=False)
    monkeypatch.setenv("EASEL_VENDOR_ROOT", str(tmp_path / "vendor"))
    assert vp.is_packaged() is True


@pytest.mark.skipif(os.name == "nt", reason="Unix vendor layout")
def test_web_environment_prepends_vendor_bins(tmp_path, monkeypatch):
    vendor = tmp_path / "vendor"
    ffmpeg_bin = vendor / "ffmpeg" / "bin"
    node_bin = vendor / "node" / "bin"
    for directory, name in ((ffmpeg_bin, "ffmpeg"), (node_bin, "node")):
        directory.mkdir(parents=True)
        path = directory / name
        path.write_text("#!/bin/sh\nexit 0\n", encoding="utf-8")
        path.chmod(0o755)
    monkeypatch.setenv("EASEL_VENDOR_ROOT", str(vendor))
    empty = tmp_path / "empty"
    empty.mkdir()
    result = runtime_env.web_environment({"PATH": str(empty), "EASEL_VENDOR_ROOT": str(vendor)})
    parts = result["PATH"].split(os.pathsep)
    assert str(ffmpeg_bin) in parts[:3]
    assert str(node_bin) in parts[:3]
    assert runtime_env.shutil.which("ffmpeg", path=result["PATH"]) == str(ffmpeg_bin / "ffmpeg")
    assert runtime_env.shutil.which("node", path=result["PATH"]) == str(node_bin / "node")


def test_apply_private_tmpdir_uses_data_dir(tmp_path):
    data = tmp_path / "Easel"
    result = runtime_env.apply_private_tmpdir({"EASEL_DATA_DIR": str(data), "TMPDIR": "/tmp"})
    expected_tmp = data / "tmp"
    expected_cache = data / "cache"
    assert result["TMPDIR"] == str(expected_tmp)
    assert result["XDG_CACHE_HOME"] == str(expected_cache)
    assert expected_tmp.is_dir() and expected_cache.is_dir()
    assert (expected_cache / "openclaw").is_dir()
    if hasattr(os, "getuid"):
        assert (expected_cache / f"openclaw-{os.getuid()}").is_dir()


def test_apply_private_tmpdir_noop_without_sandbox_dirs():
    original = {"TMPDIR": "/tmp", "PATH": "/usr/bin"}
    assert runtime_env.apply_private_tmpdir(original) == original


@pytest.mark.skipif(os.name == "nt", reason="Unix vendor layout")
def test_openclaw_base_cmd_prefers_vendor(tmp_path, monkeypatch):
    oc.openclaw_base_cmd.cache_clear()
    vendor = tmp_path / "vendor"
    node = vendor / "node" / "bin" / "node"
    node.parent.mkdir(parents=True)
    node.write_text("#!/bin/sh\n", encoding="utf-8")
    node.chmod(0o755)
    mjs = vendor / "openclaw" / "node_modules" / "openclaw" / "openclaw.mjs"
    mjs.parent.mkdir(parents=True)
    mjs.write_text("// vendor\n", encoding="utf-8")
    monkeypatch.setenv("EASEL_VENDOR_ROOT", str(vendor))
    monkeypatch.setattr(oc.shutil, "which", lambda _c: None)
    try:
        cmd = oc.openclaw_base_cmd()
        assert cmd == [str(node.resolve()), str(mjs.resolve())] or cmd[0].endswith("/node")
        assert Path(cmd[0]).name == "node"
        assert cmd[1].endswith("openclaw.mjs")
    finally:
        oc.openclaw_base_cmd.cache_clear()


def _load_install_tool(name: str):
    import importlib.util
    import sys

    path = Path(__file__).resolve().parents[1] / "skills" / "shared" / "scripts" / "install_tool.py"
    spec = importlib.util.spec_from_file_location(name, path)
    mod = importlib.util.module_from_spec(spec)
    assert spec.loader is not None
    sys.modules[name] = mod
    spec.loader.exec_module(mod)
    return mod


def test_install_tool_packaged_blocks_builtin(tmp_path, monkeypatch):
    mod = _load_install_tool("install_tool_under_test")
    monkeypatch.setenv("EASEL_PACKAGED", "1")
    monkeypatch.setenv("EASEL_VENDOR_ROOT", str(tmp_path / "vendor"))
    tool = next(t for t in mod.TOOLS if t.id == "ffmpeg")
    monkeypatch.setattr(mod, "check_tool", lambda *_a, **_k: {
        "id": "ffmpeg", "state": "missing", "version": None, "detail": None})
    result = mod.install_tool(tool, python="/usr/bin/python3")
    assert result["state"] == "fail"
    assert "内置" in (result.get("detail") or "")


def test_install_tool_model_dir_honours_env(tmp_path, monkeypatch):
    mod = _load_install_tool("install_tool_model_dir")
    models = tmp_path / "app-models"
    monkeypatch.setenv("EASEL_MODELS_DIR", str(models))
    assert mod._whisper_model_dir() == models / "whisper-large-v3"
    dest = models / "whisper-large-v3"
    dest.mkdir(parents=True)
    (dest / "model.bin").write_bytes(b"x")
    ok, detail = mod._pyfn_check_model()
    assert ok is True
    assert "就绪" in detail


def test_resolve_python_keeps_venv_entrypoint(tmp_path, monkeypatch):
    """Vendor venv python often symlinks to a base interpreter; must not realpath away."""
    import os

    mod = _load_install_tool("install_tool_resolve_python")
    vendor = tmp_path / "sidecar"
    bin_dir = vendor / "python" / "bin"
    bin_dir.mkdir(parents=True)
    base = tmp_path / "base-python"
    base.write_text("#!/bin/sh\n", encoding="utf-8")
    base.chmod(0o755)
    entry = bin_dir / ("python.exe" if os.name == "nt" else "python3")
    if os.name == "nt":
        entry.write_bytes(b"MZ")
    else:
        entry.symlink_to(base)

    monkeypatch.setenv("EASEL_VENDOR_ROOT", str(vendor))
    mod._PY_LIST = None
    resolved = mod.resolve_python()
    assert os.path.normcase(resolved) == os.path.normcase(os.path.abspath(str(entry)))
    assert Path(resolved).resolve() == base.resolve()  # symlink target differs
    assert Path(resolved) != base.resolve()
