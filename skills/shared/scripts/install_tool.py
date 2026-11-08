#!/usr/bin/env python3
"""install_tool.py — 环境工具一键安装器（检测 → 一键装 → 装后校验）。

「设置面板 · 环境安装」页、独立安装版（拷到任意机器）与各技能的共用引擎：
- 配方表：每个工具 = 怎么认（check）+ 怎么装（策略链，自动降级）+ 中文说明
- 策略链依次尝试（pip → winget → choco → 直接下载），装完重跑 check，认到才算成
- 0 提问；--json 全程可机读（面板 / agent 直接消费）

子命令：
    list                        配方总览（含本机状态）
    check [id ...]              体检（默认全量；--json 机读）
    install <id> [<id> ...]     一键安装（--dir 给「工程目录类」工具）
    selftest                    自检（离线，不装任何东西）

约束：仅标准库、Python 3.11 兼容、无交互。
"""
from __future__ import annotations

import argparse
import json
import os
import re
import shutil
import subprocess
import sys
from dataclasses import dataclass
from pathlib import Path

# ═══════════════════════════════════════════════════════════════════════
# 工具配方
#   check[0] 为 "@pyfn:<名字>" 时走内置函数检查；否则按 argv 跑（占位符：
#   {python} = 解析出的目标解释器；{dir} = --dir 传入的工程目录，只能整元素
#   替换 —— 目录是外部输入，拼进 -c 源码文本会被引号逃逸成任意代码）
#   install = [(策略名, argv[, 超时秒]), ...] 依次尝试
# ═══════════════════════════════════════════════════════════════════════


@dataclass
class Tool:
    id: str
    name: str
    group: str          # rm（视频产线套件）| pub（发布链）| common（常用库）
    desc: str
    check: list[str]
    install: list[tuple]
    needs_dir: bool = False
    big: bool = False   # 大件（面板上标注体积/耗时）


def _pip_chain(*pkgs: str, timeout: int = 1200) -> list[tuple]:
    """Install via uv pip (uv venvs often lack ``pip``), then ensurepip + python -m pip."""
    index = "https://pypi.tuna.tsinghua.edu.cn/simple"
    uv_base = ["uv", "pip", "install", "--python", "{python}", "--upgrade", *pkgs]
    uv_mirror = [*uv_base, "-i", index]
    # uv-created .venv has no pip module until bootstrapped.
    ensure = ["{python}", "-m", "ensurepip", "--upgrade"]
    base = ["{python}", "-m", "pip", "install", "--upgrade",
            "--timeout", "60", "--retries", "5", *pkgs]
    mirror = [*base, "-i", index]
    return [
        ("uv pip（默认源）", uv_base, timeout),
        ("uv pip（清华镜像）", uv_mirror, timeout),
        ("ensurepip 补齐 pip", ensure, 120),
        ("pip 安装（默认源）", base, timeout),
        ("pip 安装（清华镜像）", mirror, timeout),
    ]


def _whisper_model_dir() -> Path:
    """Canonical Whisper large-v3 directory (honours EASEL_MODELS_DIR)."""
    raw = (os.environ.get("EASEL_MODELS_DIR") or "").strip()
    base = Path(raw).expanduser() if raw else Path.home() / "models"
    return base / "whisper-large-v3"


def _whisper_model_py() -> str:
    dest = str(_whisper_model_dir()).replace("\\", "\\\\").replace("'", "\\'")
    return (
        "import os;os.environ.setdefault('HF_ENDPOINT','https://hf-mirror.com');"
        "from huggingface_hub import snapshot_download;"
        f"print(snapshot_download('Systran/faster-whisper-large-v3',"
        f"local_dir=os.path.expanduser('{dest}')))"
    )


def _is_packaged() -> bool:
    host = (os.environ.get("EASEL_HOST_ENV") or "").strip().lower()
    if host in ("1", "true", "yes", "on"):
        return False
    flag = (os.environ.get("EASEL_PACKAGED") or "").strip().lower()
    if flag in ("1", "true", "yes", "on"):
        return True
    return bool((os.environ.get("EASEL_VENDOR_ROOT") or "").strip())


# System-level installs blocked when packaged (expect vendor-bundled runtimes).
# Pip packages (fw / pylibs / pw) may still install into the running interpreter.
_PACKAGED_BUILTIN_IDS = frozenset({"node", "ffmpeg", "python"})
# Large / writable-dir assets still installable in packaged mode.
_PACKAGED_ON_DEMAND_IDS = frozenset({"model", "rmdeps", "shell", "pw", "cft", "biliup", "fw", "pylibs"})


def _pyfn_check_cft() -> tuple[bool, str]:
    import glob
    la = os.environ.get("LOCALAPPDATA", "")
    pf, pf86 = os.environ.get("PROGRAMFILES", ""), os.environ.get("PROGRAMFILES(X86)", "")
    cands: list[str] = []
    for base in (pf, pf86):
        if base:
            cands += glob.glob(os.path.join(base, "Google", "Chrome", "Application", "*", "chrome.exe"))
    if la:
        cands += glob.glob(os.path.join(la, "Google", "Chrome for Testing", "*", "chrome.exe"))
        cands += glob.glob(os.path.join(la, "ms-playwright", "chromium-*", "chrome-win64", "chrome.exe"))
    w = shutil.which("chrome")
    if w:
        cands.append(w)
    if cands:
        return True, Path(sorted(cands)[-1]).parent.parent.name or "已装"
    return False, ""


def _pyfn_check_model() -> tuple[bool, str]:
    d = _whisper_model_dir()
    try:
        if d.is_dir() and any(d.iterdir()):
            return True, "模型目录已就绪"
    except OSError:
        pass
    return False, ""


_PYFN = {"cft": _pyfn_check_cft, "model": _pyfn_check_model}


def _tools() -> list[Tool]:
    """Build the recipe table (model install argv needs a live EASEL_MODELS_DIR)."""
    return [
    # ── 视频产线套件（Remotion）──
    Tool("node", "Node.js", "rm", "rm 运行时 · 建议 24 LTS",
         ["node", "-v"],
         [("下载官方 Node 到数据目录", ["@pyfn:install_node"], 1800),
          ("brew · node", ["brew", "install", "node"], 900),
          ("winget · OpenJS.NodeJS.LTS",
           ["winget", "install", "-e", "--id", "OpenJS.NodeJS.LTS",
            "--accept-source-agreements", "--accept-package-agreements"], 900)]),
    Tool("ffmpeg", "ffmpeg", "rm", "full build · lut3d / nlmeans 等滤镜齐",
         ["ffmpeg", "-version"],
         [("brew · ffmpeg", ["brew", "install", "ffmpeg"], 900),
          ("winget · Gyan.FFmpeg",
           ["winget", "install", "-e", "--id", "Gyan.FFmpeg",
            "--accept-source-agreements", "--accept-package-agreements"], 900),
          ("choco · ffmpeg", ["choco", "install", "ffmpeg", "-y"], 900)]),
    Tool("python", "Python", "rm", "3.11+ · 工具与门脚本运行用",
         ["{python}", "--version"],
         [("winget · Python.Python.3.13",
           ["winget", "install", "-e", "--id", "Python.Python.3.13",
            "--accept-source-agreements", "--accept-package-agreements"], 900)]),
    Tool("fw", "faster-whisper", "rm", "GPU 转录（cu121）",
         ["{python}", "-c", "import faster_whisper as f;print(getattr(f,'__version__','ok'))"],
         _pip_chain("faster-whisper", timeout=1800)),
    Tool("model", "Whisper large-v3 模型", "rm", "约 3.1GB · hf-mirror 直拉 · 不入包",
         ["@pyfn:model"],
         _pip_chain("huggingface_hub", timeout=600)
         + [("hf-mirror 下载 large-v3", ["{python}", "-c", _whisper_model_py()], 7200)],
         big=True),
    Tool("rmdeps", "Remotion 工程依赖", "rm", "蓝本内置 · npm ci / npm install（镜像加速）",
         ["{python}", "-c",
          "import os,sys;sys.exit(0 if os.path.isdir(os.path.join(sys.argv[1],'node_modules')) else 1)",
          "{dir}"],
         [("npm ci · npmmirror 镜像",
           ["npm", "ci", "--registry=https://registry.npmmirror.com"], 1800),
          ("npm install · npmmirror 镜像",
           ["npm", "install", "--registry=https://registry.npmmirror.com"], 1800)],
         needs_dir=True),
    Tool("shell", "Chrome Headless Shell", "rm", "渲染用 · 随 Remotion 下载",
         ["@pyfn:shell"],
         [("npmmirror 下载 chrome-headless-shell", ["@pyfn:install_shell"], 1800),
          ("npm exec remotion browser ensure",
           ["npm", "exec", "--no", "--", "remotion", "browser", "ensure"], 1800),
          ("npx remotion browser ensure",
           ["npx", "--yes", "remotion", "browser", "ensure"], 1800)],
         needs_dir=True),
    # ── 发布链 ──
    # PyPI 的 biliup 轮子只提供 stream_gears API，不再带 `biliup` 命令行；
    # 设置面板必须下官方 biliupR 二进制，pip 装完也会校验失败。
    Tool("biliup", "biliup", "pub", "B站投稿 CLI · 官方二进制",
         ["biliup", "--version"],
         [("下载官方 biliupR 二进制", ["@pyfn:install_biliup"], 1800)]),
    Tool("pw", "Playwright Chromium", "pub", "小红书 / 快手 / 知乎 发布链浏览器",
         ["{python}", "-c", "import playwright;print('playwright ok')"],
         _pip_chain("playwright")
         + [("下载 Chromium", ["{python}", "-m", "playwright", "install", "chromium"], 1800)]),
    Tool("cft", "Chrome for Testing", "pub", "登录态浏览器 · 平台登录用",
         ["@pyfn:cft"],
         [("playwright 自带 Chromium", ["{python}", "-m", "playwright", "install", "chromium"], 1800)]),
    # ── 常用库 ──
    Tool("pylibs", "常用 Python 库", "common", "Pillow · edge-tts · pdfplumber · requests",
         ["{python}", "-c", "import PIL,edge_tts,pdfplumber,requests;print('4/4 ok')"],
         _pip_chain("Pillow", "edge-tts", "pdfplumber", "requests")),
    ]


TOOLS = _tools()

GROUP_NAMES = {"rm": "视频产线套件（Remotion）", "pub": "发布链", "common": "常用库"}

# ═══════════════════════════════════════════════════════════════════════
# 解释器解析：优先「Scripts 目录已在 PATH 上」的（装完 CLI 直接可见）
# ═══════════════════════════════════════════════════════════════════════

_PY_LIST: list[str] | None = None


def _candidate_pythons() -> list[str]:
    out: list[str] = []
    py = shutil.which("py")
    if py:
        try:
            r = subprocess.run([py, "-0p"], capture_output=True, text=True,
                               encoding="utf-8", errors="replace", timeout=20)
            out += re.findall(r"([A-Za-z]:\\[^\r\n]*?python\.exe)", r.stdout)
        except Exception:  # noqa: BLE001
            pass
    for name in ("python", "python3"):
        p = shutil.which(name)
        if p:
            out.append(p)
    la = os.environ.get("LOCALAPPDATA", "")
    if la:
        out += [str(Path(la) / "Programs" / "Python" / f"Python3{v}" / "python.exe") for v in (13, 12, 11)]
    out += ["C:/Python314/python.exe", "C:/Python313/python.exe", "C:/Python312/python.exe"]
    seen, uniq = set(), []
    for p in out:
        key = os.path.normcase(os.path.abspath(p))
        if key not in seen and os.path.isfile(p):
            seen.add(key)
            uniq.append(os.path.abspath(p))
    return uniq


def _scripts_dir(python: str) -> str:
    try:
        r = subprocess.run([python, "-c", "import sysconfig;print(sysconfig.get_path('scripts'))"],
                           capture_output=True, text=True, encoding="utf-8",
                           errors="replace", timeout=30)
        return r.stdout.strip()
    except Exception:  # noqa: BLE001
        return ""


def _python_version(python: str) -> tuple:
    try:
        r = subprocess.run([python, "-c", "import sys;print('%d.%d'%sys.version_info[:2])"],
                           capture_output=True, text=True, encoding="utf-8",
                           errors="replace", timeout=30)
        return tuple(int(x) for x in r.stdout.strip().split("."))
    except Exception:  # noqa: BLE001
        return (0, 0)


def resolve_python() -> str:
    """选目标解释器；结果缓存。可选 --python 覆盖（见 main）。"""
    global _PY_LIST
    if _PY_LIST:
        return _PY_LIST[0]
    vendor = (os.environ.get("EASEL_VENDOR_ROOT") or "").strip()
    if vendor:
        root = Path(vendor).expanduser()
        names = ("python.exe", "python") if os.name == "nt" else ("python3", "python")
        for directory in (root / "python" / "bin", root / "python" / "Scripts", root / "python"):
            for name in names:
                cand = directory / name
                if cand.is_file():
                    # Keep the venv entrypoint path. Path.resolve() follows the
                    # base-interpreter symlink and drops site-packages (fw etc.).
                    _PY_LIST = [os.path.abspath(str(cand))]
                    return _PY_LIST[0]
    path_env = os.environ.get("PATH", "").lower()
    scored = []
    for p in _candidate_pythons():
        sd = _scripts_dir(p).lower()
        scored.append((bool(sd) and sd in path_env, _python_version(p), p))
    scored.sort(key=lambda t: (t[0], t[1]), reverse=True)
    _PY_LIST = [t[2] for t in scored]
    if not _PY_LIST:
        _die("找不到任何可用的 Python 解释器", 3)
    return _PY_LIST[0]


# ═══════════════════════════════════════════════════════════════════════
# 执行
# ═══════════════════════════════════════════════════════════════════════


def _writable_bin_dir() -> Path:
    """Prefer vendor/bin when writable; else EASEL_DATA_DIR/bin; else ~/.local/bin."""
    candidates: list[Path] = []
    vendor = (os.environ.get("EASEL_VENDOR_ROOT") or "").strip()
    if vendor:
        candidates.append(Path(vendor).expanduser() / "bin")
    data = (os.environ.get("EASEL_DATA_DIR") or "").strip()
    if data:
        candidates.append(Path(data).expanduser() / "bin")
    candidates.append(Path.home() / ".local" / "bin")
    for cand in candidates:
        try:
            cand.mkdir(parents=True, exist_ok=True)
            probe = cand / ".easel-write-test"
            probe.write_text("ok", encoding="utf-8")
            probe.unlink(missing_ok=True)
            return cand
        except OSError:
            continue
    raise RuntimeError("找不到可写的 bin 目录（EASEL_VENDOR_ROOT/bin 或 EASEL_DATA_DIR/bin）")


def _biliup_asset() -> tuple[str, str]:
    """Return (archive_name, version_tag) for the current platform."""
    import platform

    tag = (os.environ.get("EASEL_BILIUP_VERSION") or "v1.3.5").strip()
    sysname = platform.system().lower()
    machine = platform.machine().lower()
    if sysname == "darwin":
        arch = "aarch64" if machine in ("arm64", "aarch64") else "x86_64"
        return f"biliupR-{tag}-{arch}-macos.tar.xz", tag
    if sysname == "windows":
        return f"biliupR-{tag}-x86_64-windows.zip", tag
    arch = "aarch64" if machine in ("arm64", "aarch64") else "x86_64"
    return f"biliupR-{tag}-{arch}-linux.tar.xz", tag


def _download(url: str, dest: Path, timeout: int = 600) -> None:
    import urllib.request

    dest.parent.mkdir(parents=True, exist_ok=True)
    req = urllib.request.Request(url, headers={"User-Agent": "Unisyn-install_tool/1.0"})
    with urllib.request.urlopen(req, timeout=timeout) as resp, open(dest, "wb") as out:
        while True:
            chunk = resp.read(1024 * 256)
            if not chunk:
                break
            out.write(chunk)


def _pyfn_install_biliup(*, python: str = "", dir_: str | None = None) -> tuple[bool, str]:
    """Download official biliupR CLI into a writable bin dir on PATH search."""
    import platform
    import tarfile
    import tempfile
    import zipfile
    _ = python, dir_  # shared @pyfn call signature

    archive_name, tag = _biliup_asset()
    mirrors = [
        f"https://github.com/biliup/biliup/releases/download/{tag}/{archive_name}",
        f"https://ghproxy.net/https://github.com/biliup/biliup/releases/download/{tag}/{archive_name}",
        f"https://mirror.ghproxy.com/https://github.com/biliup/biliup/releases/download/{tag}/{archive_name}",
    ]
    explicit = (os.environ.get("EASEL_BILIUP_URL") or "").strip()
    if explicit:
        mirrors = [explicit, *mirrors]

    bin_dir = _writable_bin_dir()
    exe_name = "biliup.exe" if os.name == "nt" else "biliup"
    target = bin_dir / exe_name

    last_err = ""
    with tempfile.TemporaryDirectory(prefix="biliupR-") as tmp:
        tmp_path = Path(tmp)
        archive = tmp_path / archive_name
        for url in mirrors:
            try:
                _download(url, archive)
                last_err = ""
                break
            except Exception as e:  # noqa: BLE001
                last_err = f"{type(e).__name__}: {e}"
                archive.unlink(missing_ok=True)
        if last_err or not archive.is_file():
            return False, f"下载失败：{last_err or '无文件'}"

        extract_dir = tmp_path / "out"
        extract_dir.mkdir()
        try:
            if archive_name.endswith(".zip"):
                with zipfile.ZipFile(archive) as zf:
                    zf.extractall(extract_dir)
            else:
                with tarfile.open(archive, "r:*") as tf:
                    # Python 3.12+ warns; 3.14 will filter by default.
                    try:
                        tf.extractall(extract_dir, filter="data")
                    except TypeError:
                        tf.extractall(extract_dir)
        except Exception as e:  # noqa: BLE001
            return False, f"解压失败：{type(e).__name__}: {e}"

        candidates = [p for p in extract_dir.rglob(exe_name) if p.is_file()]
        if not candidates and os.name != "nt":
            candidates = [p for p in extract_dir.rglob("biliupR") if p.is_file()]
        if not candidates:
            return False, f"压缩包内未找到 {exe_name}"
        src = candidates[0]
        data = src.read_bytes()
        target.write_bytes(data)
        try:
            target.chmod(0o755)
        except OSError:
            pass
        # Windows: keep .exe name; Unix consumers call `biliup`.
        if os.name != "nt" and target.name != "biliup":
            alias = bin_dir / "biliup"
            alias.write_bytes(data)
            try:
                alias.chmod(0o755)
            except OSError:
                pass

    # Smoke the binary we just wrote (avoid PATH race).
    try:
        proc = subprocess.run(
            [str(target), "--version"],
            capture_output=True, text=True, encoding="utf-8", errors="replace",
            timeout=30)
        if proc.returncode != 0:
            return False, f"二进制无法运行：{(proc.stderr or proc.stdout or '')[:120]}"
        ver = (proc.stdout or proc.stderr or "").strip().splitlines()
        return True, (ver[0] if ver else str(target))
    except Exception as e:  # noqa: BLE001
        # Some builds may not support --version; existence + exec bit is enough.
        if target.is_file():
            return True, f"{platform.system()} · {target}"
        return False, f"{type(e).__name__}: {e}"


def _node_arch(dir_: str | None = None) -> str:
    """Match Remotion's process.arch (Rosetta Node → x64 even on Apple Silicon)."""
    try:
        proc = subprocess.run(
            ["node", "-p", "process.arch"],
            cwd=dir_ or None, capture_output=True, text=True,
            encoding="utf-8", errors="replace", timeout=15)
        arch = (proc.stdout or "").strip().lower()
        if arch:
            return arch
    except Exception:  # noqa: BLE001
        pass
    import platform as _plat
    m = _plat.machine().lower()
    if m in ("arm64", "aarch64"):
        return "arm64"
    if m in ("x86_64", "amd64", "x64"):
        return "x64"
    return m or "x64"


def _chrome_headless_platform(dir_: str | None = None) -> str:
    """Same labels as @remotion/renderer BrowserFetcher.getPlatform()."""
    import platform as _plat
    arch = _node_arch(dir_)
    sysname = _plat.system().lower()
    if sysname == "darwin":
        return "mac-arm64" if arch == "arm64" else "mac-x64"
    if sysname == "windows":
        return "win64"
    return "linux-arm64" if arch == "arm64" else "linux64"


def _remotion_chrome_version(dir_: str) -> str:
    try:
        proc = subprocess.run(
            ["node", "-e",
             "console.log(require('@remotion/renderer/dist/browser/"
             "get-chrome-download-url.js').TESTED_VERSION)"],
            cwd=dir_, capture_output=True, text=True,
            encoding="utf-8", errors="replace", timeout=30)
        ver = (proc.stdout or "").strip()
        if ver and ver[0].isdigit():
            return ver
    except Exception:  # noqa: BLE001
        pass
    return "149.0.7790.0"


def _pyfn_install_shell(*, python: str = "", dir_: str | None = None) -> tuple[bool, str]:
    """Download Chrome Headless Shell via npmmirror (Google CDN is often slow in CN)."""
    import platform as _plat
    import shutil
    import tempfile
    import zipfile

    if not dir_:
        return False, "需要 --dir（Remotion 工程目录）"
    root = Path(dir_)
    if not (root / "package.json").is_file():
        return False, f"{dir_} 不是 Remotion 工程（缺 package.json）"
    if not (root / "node_modules").is_dir():
        return False, "请先安装 Remotion 工程依赖（rmdeps）"

    plat = _chrome_headless_platform(dir_)
    version = _remotion_chrome_version(dir_)
    cache = root / "node_modules" / ".remotion" / "chrome-headless-shell"
    platform_dir = cache / plat
    exe_name = "chrome-headless-shell.exe" if os.name == "nt" else "chrome-headless-shell"
    # Already present?
    existing = sorted(platform_dir.rglob(exe_name)) if platform_dir.is_dir() else []
    ver_file = cache / "VERSION"
    if existing and ver_file.is_file() and ver_file.read_text(encoding="utf-8").strip() == version:
        return True, f"已缓存 {plat} · {version}"

    zip_name = f"chrome-headless-shell-{plat}.zip"
    mirrors = [
        f"https://cdn.npmmirror.com/binaries/chrome-for-testing/{version}/{plat}/{zip_name}",
        f"https://storage.googleapis.com/chrome-for-testing-public/{version}/{plat}/{zip_name}",
    ]
    explicit = (os.environ.get("EASEL_CHROME_HEADLESS_URL") or "").strip()
    if explicit:
        mirrors = [explicit, *mirrors]

    last_err = ""
    with tempfile.TemporaryDirectory(prefix="chs-") as tmp:
        archive = Path(tmp) / zip_name
        for url in mirrors:
            try:
                print(f"    ↓ {url}", file=sys.stderr)
                _download(url, archive, timeout=900)
                last_err = ""
                break
            except Exception as e:  # noqa: BLE001
                last_err = f"{type(e).__name__}: {e}"
                archive.unlink(missing_ok=True)
        if last_err or not archive.is_file():
            return False, f"下载失败：{last_err or '无文件'}"

        if platform_dir.exists():
            shutil.rmtree(platform_dir, ignore_errors=True)
        platform_dir.mkdir(parents=True, exist_ok=True)
        try:
            with zipfile.ZipFile(archive) as zf:
                zf.extractall(platform_dir)
        except Exception as e:  # noqa: BLE001
            return False, f"解压失败：{type(e).__name__}: {e}"

    cache.mkdir(parents=True, exist_ok=True)
    ver_file.write_text(version + "\n", encoding="utf-8")
    bins = sorted(platform_dir.rglob(exe_name))
    if not bins:
        return False, f"解压后未找到 {exe_name}"
    for b in bins:
        try:
            b.chmod(b.stat().st_mode | 0o111)
        except OSError:
            pass
    return True, f"{_plat.system()} · {plat} · {version}"


def _pyfn_install_node(*, python: str = "", dir_: str | None = None) -> tuple[bool, str]:
    """Download official Node.js into EASEL_DATA_DIR and link binaries into …/bin."""
    import platform
    import shutil
    import tarfile
    import tempfile
    import zipfile

    _ = python, dir_
    version = (os.environ.get("EASEL_NODE_VERSION") or "24.16.0").strip()
    sysname = platform.system().lower()
    machine = platform.machine().lower()
    if sysname == "darwin":
        plat = "darwin-arm64" if machine in ("arm64", "aarch64") else "darwin-x64"
        archive = f"node-v{version}-{plat}.tar.gz"
    elif sysname == "windows":
        plat = "win-x64"
        archive = f"node-v{version}-{plat}.zip"
    else:
        plat = "linux-arm64" if machine in ("arm64", "aarch64") else "linux-x64"
        archive = f"node-v{version}-{plat}.tar.gz"

    mirrors = [
        f"https://npmmirror.com/mirrors/node/v{version}/{archive}",
        f"https://nodejs.org/dist/v{version}/{archive}",
    ]
    explicit = (os.environ.get("EASEL_NODE_URL") or "").strip()
    if explicit:
        mirrors = [explicit, *mirrors]

    data = (os.environ.get("EASEL_DATA_DIR") or "").strip()
    if not data:
        return False, "未设置 EASEL_DATA_DIR，无法落地 Node"
    root = Path(data).expanduser()
    runtime = root / "runtime" / f"node-v{version}-{plat}"
    bin_dir = _writable_bin_dir()

    if (runtime / "bin" / "node").is_file() or (runtime / "node.exe").is_file():
        _link_node_bins(runtime, bin_dir)
        return True, f"已缓存 Node {version}"

    last_err = ""
    with tempfile.TemporaryDirectory(prefix="node-") as tmp:
        archive_path = Path(tmp) / archive
        for url in mirrors:
            try:
                print(f"    ↓ {url}", file=sys.stderr)
                _download(url, archive_path, timeout=900)
                last_err = ""
                break
            except Exception as e:  # noqa: BLE001
                last_err = f"{type(e).__name__}: {e}"
                archive_path.unlink(missing_ok=True)
        if last_err or not archive_path.is_file():
            return False, f"下载 Node 失败：{last_err or '无文件'}"

        extract_dir = Path(tmp) / "out"
        extract_dir.mkdir()
        try:
            if archive.endswith(".zip"):
                with zipfile.ZipFile(archive_path) as zf:
                    zf.extractall(extract_dir)
            else:
                with tarfile.open(archive_path, "r:*") as tf:
                    try:
                        tf.extractall(extract_dir, filter="data")
                    except TypeError:
                        tf.extractall(extract_dir)
        except Exception as e:  # noqa: BLE001
            return False, f"解压 Node 失败：{type(e).__name__}: {e}"

        kids = [p for p in extract_dir.iterdir() if p.is_dir()]
        if not kids:
            return False, "Node 压缩包结构异常"
        src = kids[0]
        if runtime.exists():
            shutil.rmtree(runtime, ignore_errors=True)
        runtime.parent.mkdir(parents=True, exist_ok=True)
        shutil.move(str(src), str(runtime))

    _link_node_bins(runtime, bin_dir)
    node_bin = runtime / ("node.exe" if os.name == "nt" else "bin/node")
    try:
        proc = subprocess.run(
            [str(node_bin), "-v"],
            capture_output=True, text=True, encoding="utf-8", errors="replace",
            timeout=30)
        ver = (proc.stdout or "").strip() or version
    except Exception as e:  # noqa: BLE001
        return False, f"Node 无法运行：{e}"
    return True, ver


def _link_node_bins(runtime: Path, bin_dir: Path) -> None:
    bin_dir.mkdir(parents=True, exist_ok=True)
    if os.name == "nt":
        src_bin = runtime
        names = ("node.exe", "npm.cmd", "npx.cmd")
    else:
        src_bin = runtime / "bin"
        names = ("node", "npm", "npx", "corepack")
    for name in names:
        src = src_bin / name
        if not src.exists():
            continue
        dest = bin_dir / name
        try:
            if dest.is_symlink() or dest.exists():
                dest.unlink()
            dest.symlink_to(src)
        except OSError:
            # Fall back to copy when symlink is blocked.
            import shutil
            shutil.copy2(src, dest)
            try:
                dest.chmod(0o755)
            except OSError:
                pass


_INSTALL_PYFN = {
    "install_biliup": _pyfn_install_biliup,
    "install_shell": _pyfn_install_shell,
    "install_node": _pyfn_install_node,
}


def _search_dirs(python: str) -> list[str]:
    """CLI 可能落地的目录：vendor/data bin + 解释器 Scripts + 用户级 Scripts。"""
    dirs = []
    for key in ("EASEL_VENDOR_ROOT", "EASEL_DATA_DIR"):
        raw = (os.environ.get(key) or "").strip()
        if not raw:
            continue
        root = Path(raw).expanduser()
        dirs.append(str(root / "bin"))
        if key == "EASEL_VENDOR_ROOT":
            dirs.append(str(root / "ffmpeg" / "bin"))
            dirs.append(str(root / "python" / "bin"))
            dirs.append(str(root / "python" / "Scripts"))
    dirs.append(str(Path.home() / ".local" / "bin"))
    sd = _scripts_dir(python)
    if sd:
        dirs.append(sd)
    try:
        r = subprocess.run([python, "-m", "site", "--user-base"],
                           capture_output=True, text=True, encoding="utf-8",
                           errors="replace", timeout=30)
        ub = r.stdout.strip()
        if ub:
            dirs.append(os.path.join(ub, "Scripts"))
            v = _python_version(python)
            if all(v):
                dirs.append(os.path.join(ub, f"Python{v[0]}{v[1]}", "Scripts"))
    except Exception:  # noqa: BLE001
        pass
    appdata = os.environ.get("APPDATA", "")
    v = _python_version(python)
    if appdata and all(v):
        dirs.append(os.path.join(appdata, "Python", f"Python{v[0]}{v[1]}", "Scripts"))
    # de-dupe while preserving order
    out: list[str] = []
    seen: set[str] = set()
    for d in dirs:
        key = os.path.normcase(os.path.abspath(d))
        if key in seen:
            continue
        seen.add(key)
        out.append(d)
    return out


def _find_cli(name: str, python: str) -> str | None:
    p = shutil.which(name)
    if p:
        return p
    for d in _search_dirs(python):
        for ext in (".exe", ".cmd", ".bat", ""):
            cand = os.path.join(d, name + ext)
            if os.path.isfile(cand):
                return cand
    return None


def _die(msg: str, code: int = 1) -> None:
    print(f"ERROR: {msg}", file=sys.stderr)
    sys.exit(code)


def _fill(argv: list[str], python: str, dir_: str | None) -> list[str]:
    """占位符替换。{dir} 只认「整个元素就是 {dir}」的写法，永远作为独立 argv
    元素落地 —— 拼进更大的串（尤其 -c 的源码文本）时目录里一个引号就能逃逸
    成可执行代码，故此处直接拒绝，属结构性保证而非约定。"""
    out = []
    for a in argv:
        a = a.replace("{python}", python)
        if "{dir}" in a:
            if a != "{dir}":
                raise ValueError(f"配方非法：{{dir}} 只能单独成一个参数，不可拼进 {a!r}")
            if not dir_:
                raise ValueError("需要 --dir")
            a = dir_
        out.append(a)
    return out


def _err_tail(proc) -> str:
    """从输出里挑「像错误的那一行」（跳过进度条碎片）。"""
    text = ((proc.stderr or "") + "\n" + (proc.stdout or "")).replace("\r", "\n")
    lines = [l.strip() for l in text.split("\n") if l.strip()]
    bad = [l for l in lines
           if re.search(r"error|失败|failed|could not|no matching|not found|traceback", l, re.I)]
    pick = bad[-1] if bad else (lines[-1] if lines else "")
    return pick[:140]


def _run(argv: list[str], *, cwd: str | None = None, timeout: int = 600):
    exe = shutil.which(argv[0]) or argv[0]
    if os.name == "nt" and exe.lower().endswith((".cmd", ".bat")):
        # Windows 通病：CreateProcess 不认 .cmd shim（npm/npx 等），走 cmd /c
        # —— 仅限参数简单的工具；带换行/怪引号的命令不用此路径
        exe = [os.environ.get("COMSPEC", "cmd.exe"), "/c", exe]
    else:
        exe = [exe]
    return subprocess.run([*exe, *argv[1:]], cwd=cwd, timeout=timeout,
                          capture_output=True, text=True,
                          encoding="utf-8", errors="replace")


def _module_file(python: str, module: str) -> str | None:
    try:
        proc = subprocess.run(
            [python, "-c", f"import {module} as m; print(getattr(m, '__file__', '') or '')"],
            capture_output=True, text=True, encoding="utf-8", errors="replace", timeout=30)
        path = (proc.stdout or "").strip()
        return path or None
    except Exception:  # noqa: BLE001
        return None


def resolve_tool_path(tool: Tool, python: str, dir_: str | None = None) -> str | None:
    """Best-effort filesystem path for「打开所在文件夹」(file or directory)."""
    tid = tool.id
    try:
        if tid == "python" and python and os.path.exists(python):
            return python
        if tid == "model":
            d = _whisper_model_dir()
            return str(d if d.exists() else d.parent)
        if tid == "rmdeps" and dir_:
            return dir_
        if tid == "shell" and dir_:
            import glob
            g = glob.glob(os.path.join(dir_, "node_modules", ".remotion", "**",
                                       "chrome-headless-shell*"), recursive=True)
            if g:
                return sorted(g)[-1]
            return os.path.join(dir_, "node_modules", ".remotion")
        if tid == "fw":
            return _module_file(python, "faster_whisper")
        if tid == "pylibs":
            return _module_file(python, "PIL")
        if tid == "pw":
            return _module_file(python, "playwright")
        if tid == "cft":
            ok, _detail = _pyfn_check_cft()
            if ok:
                # Re-scan for a concrete chrome path (check only returns version label).
                import glob
                la = os.environ.get("LOCALAPPDATA", "")
                pf = os.environ.get("PROGRAMFILES", "")
                cands: list[str] = []
                if pf:
                    cands += glob.glob(os.path.join(pf, "Google", "Chrome", "Application", "*", "chrome.exe"))
                if la:
                    cands += glob.glob(os.path.join(la, "ms-playwright", "chromium-*", "chrome-win64", "chrome.exe"))
                mac = "/Applications/Google Chrome.app"
                if os.path.isdir(mac):
                    return mac
                which = shutil.which("google-chrome") or shutil.which("chromium") or shutil.which("chrome")
                if which:
                    return which
                if cands:
                    return sorted(cands)[-1]
        if tool.check and not tool.check[0].startswith("@"):
            argv0 = tool.check[0]
            if argv0 == "{python}":
                return python if os.path.exists(python) else None
            if not argv0.startswith("{"):
                found = _find_cli(argv0, python)
                if found:
                    return found
        if tid == "biliup":
            try:
                return str(_writable_bin_dir() / ("biliup.exe" if os.name == "nt" else "biliup"))
            except Exception:  # noqa: BLE001
                return None
    except Exception:  # noqa: BLE001
        return None
    return None


def check_tool(tool: Tool, python: str, dir_: str | None = None) -> dict:
    """单个体检 → {"id","state","version","detail","path?"}；state: ok | missing | no_dir"""
    if tool.needs_dir and not dir_:
        return {"id": tool.id, "state": "no_dir", "version": None, "detail": "需要 --dir（工程目录）",
                "path": None}
    try:
        if tool.check[0].startswith("@pyfn:"):
            name = tool.check[0].split(":", 1)[1]
            if name == "shell":  # 依赖工程目录（无 dir 已在前面返回 no_dir）
                import glob
                g = glob.glob(os.path.join(dir_, "node_modules", ".remotion", "**",
                                           "chrome-headless-shell*"), recursive=True)
                path = sorted(g)[-1] if g else resolve_tool_path(tool, python, dir_)
                return {"id": tool.id, "state": "ok" if g else "missing",
                        "version": "已缓存" if g else None, "detail": None, "path": path}
            ok, detail = _PYFN[name]()
            return {"id": tool.id, "state": "ok" if ok else "missing",
                    "version": detail if ok else None, "detail": None,
                    "path": resolve_tool_path(tool, python, dir_)}
        argv = _fill(tool.check, python, dir_)
        resolved = None
        if not os.path.isabs(argv[0]):
            found = _find_cli(argv[0], python)
            if found:
                resolved = found
                argv[0] = found
        elif os.path.exists(argv[0]):
            resolved = argv[0]
        proc = _run(argv, timeout=120)
        path = resolved or resolve_tool_path(tool, python, dir_)
        if proc.returncode == 0:
            first = (proc.stdout or proc.stderr or "").strip().splitlines()
            return {"id": tool.id, "state": "ok",
                    "version": (first[0].strip()[:70] if first else "已装"), "detail": None,
                    "path": path}
        return {"id": tool.id, "state": "missing", "version": None, "detail": None, "path": path}
    except FileNotFoundError:
        return {"id": tool.id, "state": "missing", "version": None, "detail": None,
                "path": resolve_tool_path(tool, python, dir_)}
    except Exception as e:  # noqa: BLE001
        return {"id": tool.id, "state": "missing", "version": None, "detail": f"{type(e).__name__}: {e}",
                "path": resolve_tool_path(tool, python, dir_)}


def check_all(python: str, dir_: str | None = None, only: list[str] | None = None) -> list[dict]:
    """全量体检。每条结果带回元信息（name/group/group_name/desc/big），供面板与接口直接渲染。"""
    tools = [t for t in TOOLS if not only or t.id in only]
    out = []
    for t in tools:
        r = check_tool(t, python, dir_)
        if not r.get("path"):
            r["path"] = resolve_tool_path(t, python, dir_)
        r.update({"name": t.name, "group": t.group,
                  "group_name": GROUP_NAMES.get(t.group, t.group),
                  "desc": t.desc, "big": bool(t.big)})
        out.append(r)
    return out


# 读改写整个在一次 PowerShell 里做完：既避免读/写之间的竞态，也保证类型不被降级。
# 不能用 [Environment]::GetEnvironmentVariable('Path','User')：它读 REG_EXPAND_SZ 时会把
# %USERPROFILE% 这类引用**展开**成字面路径；而 SetEnvironmentVariable 写回是 REG_SZ。
# 两者一合，用户 PATH 里原有的间接引用就被永久压平、值类型也降级了（换机器/漫游配置即失效）。
# 这里用 DoNotExpandEnvironmentNames 取原值，写回时沿用原来的 ValueKind。
# 代价：不再广播 WM_SETTINGCHANGE，已开着的 Explorer/终端看不到更新 —— 与调用方
# 「新进程生效」的提示一致，新开的终端启动时直接读注册表，不受影响。
_PS_APPEND_USER_PATH = r"""
$ErrorActionPreference = 'Stop'
$key = [Microsoft.Win32.Registry]::CurrentUser.OpenSubKey('Environment', $true)
if ($null -eq $key) { exit 2 }
try {
    if ($key.GetValueNames() -contains 'Path') {
        $raw  = [string]$key.GetValue('Path', '', [Microsoft.Win32.RegistryValueOptions]::DoNotExpandEnvironmentNames)
        $kind = $key.GetValueKind('Path')
    } else {
        $raw  = ''
        $kind = [Microsoft.Win32.RegistryValueKind]::ExpandString
    }
    $want = $env:EASEL_NEW_DIR.TrimEnd('\', '/')
    foreach ($p in ($raw -split ';')) {
        if ($p -and $p.TrimEnd('\', '/') -eq $want) { exit 3 }
    }
    $sep = if ($raw -and -not $raw.EndsWith(';')) { ';' } else { '' }
    $key.SetValue('Path', ($raw + $sep + $env:EASEL_NEW_DIR), $kind)
    exit 0
} finally { $key.Close() }
"""


def _ensure_user_path(d: str) -> str:
    """把目录追加进用户 PATH（幂等）。返回 changed | present | fail | skip。

    只有 Windows 才有「用户级持久 PATH」这回事；别的平台直接 skip（不碰、也不
    往 detail 里塞失败串）。
    """
    if os.name != "nt":
        return "skip"
    ps = shutil.which("powershell") or "powershell"
    try:
        # 目录走子进程环境变量递过去，绝不拼进脚本串：PATH 里只要有一个单引号，
        # 拼串写法就会截断字面量、后半截被当 PowerShell 代码执行
        proc = subprocess.run(
            [ps, "-NoProfile", "-Command", _PS_APPEND_USER_PATH],
            capture_output=True, text=True, encoding="utf-8", errors="replace",
            timeout=60, env={**os.environ, "EASEL_NEW_DIR": d})
        return {0: "changed", 3: "present"}.get(proc.returncode, "fail")
    except Exception:  # noqa: BLE001
        return "fail"


def install_tool(tool: Tool, python: str, dir_: str | None = None) -> dict:
    """一键装：策略链依次尝试 → 装完重跑 check，认到才算成。"""
    if tool.needs_dir and not dir_:
        _die(f"{tool.id} 需要 --dir <工程目录>（{tool.desc}）", 3)
    if tool.needs_dir and not (Path(dir_) / "package.json").is_file():
        _die(f"{dir_} 里没有 package.json，不是 Remotion 工程目录", 3)

    pre = check_tool(tool, python, dir_)
    if pre["state"] == "ok":
        note = _ensure_cli_visible(tool, python)
        print(f"✓ {tool.name} 已装，跳过（{pre['version']}）{note}", file=sys.stderr)
        return {"id": tool.id, "state": "ok", "version": pre["version"],
                "strategy": "已装", "detail": note or None}

    if _is_packaged() and tool.id in _PACKAGED_BUILTIN_IDS:
        return {"id": tool.id, "state": "fail", "version": None, "strategy": None,
                "detail": "打包版已内置该运行时，禁止系统级安装；请检查 EASEL_VENDOR_ROOT"}

    # Refresh model download argv so EASEL_MODELS_DIR changes take effect.
    if tool.id == "model":
        tool = next(t for t in _tools() if t.id == "model")

    print(f"▶ 安装 {tool.name}（{tool.desc}）", file=sys.stderr)
    last_err = ""
    for label, argv, *rest in tool.install:
        timeout = int(rest[0]) if rest else 600
        print(f"  → 策略：{label}", file=sys.stderr)
        # In-process installers (official binary downloads, etc.)
        if argv and isinstance(argv[0], str) and argv[0].startswith("@pyfn:"):
            fn_name = argv[0].split(":", 1)[1]
            fn = _INSTALL_PYFN.get(fn_name)
            if fn is None:
                last_err = f"{label}: 未知安装函数 {fn_name}"
                print(f"    ✗ {last_err}", file=sys.stderr)
                continue
            try:
                try:
                    ok, detail = fn(python=python, dir_=dir_)
                except TypeError:
                    ok, detail = fn()
            except Exception as e:  # noqa: BLE001
                last_err = f"{label}: {type(e).__name__}: {e}"
                print(f"    ✗ {last_err}", file=sys.stderr)
                continue
            if not ok:
                last_err = f"{label}: {detail}"
                print(f"    ✗ {last_err}", file=sys.stderr)
                continue
            state = check_tool(tool, python, dir_)
            if state["state"] == "ok":
                note = _ensure_cli_visible(tool, python)
                print(f"    ✓ {label} 完成{note}", file=sys.stderr)
                return {"id": tool.id, "state": "ok", "version": state["version"] or detail,
                        "strategy": label, "detail": note or None}
            last_err = f"{label}: 装完校验未通过（{state['detail'] or detail or 'check 未认到'}）"
            print(f"    ✗ {last_err}", file=sys.stderr)
            continue

        argv_f = _fill(argv, python, dir_)
        try:
            proc = _run(argv_f, cwd=dir_ if tool.needs_dir else None, timeout=timeout)
        except Exception as e:  # noqa: BLE001
            last_err = f"{label}: {type(e).__name__}: {e}"
            print(f"    ✗ {last_err}", file=sys.stderr)
            continue
        if proc.returncode != 0:
            last_err = f"{label}: 退出码 {proc.returncode}" + (f" · {_err_tail(proc)}" if _err_tail(proc) else "")
            print(f"    ✗ {last_err}", file=sys.stderr)
            continue
        state = check_tool(tool, python, dir_)
        if state["state"] == "ok":
            note = _ensure_cli_visible(tool, python)
            print(f"    ✓ {label} 完成{note}", file=sys.stderr)
            return {"id": tool.id, "state": "ok", "version": state["version"],
                    "strategy": label, "detail": note or None}
        last_err = f"{label}: 装完校验未通过（{state['detail'] or 'check 未认到'}）"
        print(f"    ✗ {last_err}", file=sys.stderr)

    return {"id": tool.id, "state": "fail", "version": None,
            "strategy": None, "detail": last_err or "未知失败"}


def _ensure_cli_visible(tool: Tool, python: str) -> str:
    """CLI 类工具：装了但 PATH 上看不见时，把落地目录追加进用户 PATH（幂等）。"""
    if tool.check[0].startswith(("@", "{python}")):
        return ""
    found = shutil.which(tool.id) or _find_cli(tool.id, python)
    if not found:
        return ""
    d = os.path.dirname(found)
    r = _ensure_user_path(d)
    if r == "changed":
        return f"（已把 {d} 追加进用户 PATH，新进程生效）"
    if r == "fail":
        return f"（CLI 在 {found}，PATH 追加失败，请手动加 {d}）"
    return ""


# ═══════════════════════════════════════════════════════════════════════
# 输出
# ═══════════════════════════════════════════════════════════════════════

_MARK = {"ok": "✓", "missing": "✗", "no_dir": "·", "fail": "✗"}


def print_table(results: list[dict], python: str) -> None:
    by_id = {t.id: t for t in TOOLS}
    print(f"══ 环境体检（目标解释器：{python}）══")
    cur_group = None
    for r in results:
        t = by_id[r["id"]]
        if t.group != cur_group:
            cur_group = t.group
            print(f"\n[{GROUP_NAMES.get(cur_group, cur_group)}]")
        ver = f" · {r['version']}" if r.get("version") else ""
        note = "" if r["state"] in ("ok", "missing") else f"（{r.get('detail') or ''}）"
        print(f"  {_MARK.get(r['state'], '?')} {t.id:<9} {t.name}{ver}{note}")
    ok = sum(1 for r in results if r["state"] == "ok")
    print(f"\n就绪 {ok} / {len(results)}")


# ═══════════════════════════════════════════════════════════════════════
# 命令
# ═══════════════════════════════════════════════════════════════════════


def cmd_list(a) -> int:
    python = a.python or resolve_python()
    if a.json:
        print(json.dumps({"tools": [t.__dict__ for t in TOOLS]}, ensure_ascii=False, default=str))
        return 0
    for gid, gname in GROUP_NAMES.items():
        print(f"[{gname}]")
        for t in TOOLS:
            if t.group == gid:
                big = "（大件）" if t.big else ""
                print(f"  {t.id:<9} {t.name:<22} {t.desc}{big}")
    return 0


def cmd_check(a) -> int:
    python = a.python or resolve_python()
    results = check_all(python, a.dir, a.ids or None)
    if a.json:
        print(json.dumps({"python": python, "tools": results}, ensure_ascii=False))
    else:
        print_table(results, python)
    return 0


def cmd_install(a) -> int:
    python = a.python or resolve_python()
    by_id = {t.id: t for t in TOOLS}
    bad = [i for i in a.ids if i not in by_id]
    if bad:
        _die(f"不认识的工具：{'、'.join(bad)}（可用：{'、'.join(by_id)}）", 3)
    results = []
    for tid in a.ids:
        results.append(install_tool(by_id[tid], python, a.dir))
    if a.json:
        print(json.dumps({"python": python, "results": results}, ensure_ascii=False))
    else:
        for r in results:
            ok = r["state"] == "ok"
            print(f"{'✅' if ok else '❌'} {r['id']}"
                  + (f" · {r['version']}" if ok and r.get('version') else "")
                  + ("" if ok else f" · {r.get('detail')}"), file=sys.stderr)
    return 0 if all(r["state"] == "ok" for r in results) else 1


def cmd_selftest(_a) -> int:
    print("install_tool 自检 ...", file=sys.stderr)
    ids = [t.id for t in TOOLS]
    assert len(ids) == len(set(ids)), "工具 id 重复"
    assert set(t.group for t in TOOLS) <= set(GROUP_NAMES), "未知分组"
    for t in TOOLS:
        assert t.check and (t.check[0].startswith("@pyfn:") or len(t.check) >= 1), f"{t.id} check 异常"
        assert t.install, f"{t.id} 无安装策略"
        if t.check[0].startswith("@pyfn:"):
            _cn = t.check[0].split(":", 1)[1]
            assert _cn in _PYFN or _cn == "shell", f"{t.id} 引用了不存在的检查函数"
        for _label, argv, *_rest in t.install:
            if argv and isinstance(argv[0], str) and argv[0].startswith("@pyfn:"):
                _in = argv[0].split(":", 1)[1]
                assert _in in _INSTALL_PYFN, f"{t.id} 引用了不存在的安装函数 {_in}"
    py = resolve_python()
    assert os.path.isfile(py), "解析出的解释器不存在"
    sd = _scripts_dir(py)
    assert sd, "拿不到 Scripts 目录"
    # 体检冒烟（其中一个必须可跑通流程，不装任何东西）
    r = check_tool(TOOLS[0], py)
    assert r["state"] in ("ok", "missing"), f"check 状态异常：{r}"
    print(f"✅ selftest 通过（{len(TOOLS)} 个配方 · 解释器 {py}）", file=sys.stderr)
    return 0


def main() -> int:
    # 输出里全是中文。Windows 上 stdout 一旦是管道（被面板/agent 捕获），Python 就按
    # 系统 locale 编码（cp936/cp1252）写，配方表里的中文直接 UnicodeEncodeError 崩掉，
    # stdout 一个字节都不出 —— 调用方拿到空串，只会以为「配方表是空的」。
    # 面板的安装接口就是这么被整条废掉的：id 白名单永远为空，装什么都报「无效的工具 id」。
    for stream in (sys.stdout, sys.stderr):
        try:
            stream.reconfigure(encoding="utf-8", errors="replace")
        except (AttributeError, ValueError):  # 被重定向成非 TextIOWrapper 时忽略
            pass

    ap = argparse.ArgumentParser(
        description="环境工具一键安装器（检测 → 一键装 → 装后校验）",
        formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--python", help="目标解释器路径（默认自动解析：优先 PATH 可见者）")
    ap.add_argument("--json", action="store_true", help="机读输出（stdout 一个 JSON）")
    sub = ap.add_subparsers(dest="cmd")

    sub.add_parser("list", help="配方总览").set_defaults(func=cmd_list)

    pc = sub.add_parser("check", help="体检")
    pc.add_argument("ids", nargs="*", help="工具 id（默认全量）")
    pc.add_argument("--dir", help="工程目录（rmdeps / shell 用）")
    pc.set_defaults(func=cmd_check)

    pi = sub.add_parser("install", help="一键安装")
    pi.add_argument("ids", nargs="+", help="工具 id")
    pi.add_argument("--dir", help="工程目录（rmdeps / shell 用）")
    pi.set_defaults(func=cmd_install)

    sub.add_parser("selftest", help="自检").set_defaults(func=cmd_selftest)

    for _p in sub.choices.values():  # --json 放在子命令后也认
        _p.add_argument("--json", action="store_true", default=argparse.SUPPRESS,
                        help="机读输出（与全局 --json 等效）")

    a = ap.parse_args()
    if not getattr(a, "func", None):
        ap.print_help()
        return 1
    return a.func(a)


if __name__ == "__main__":
    sys.exit(main())
