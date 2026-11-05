from __future__ import annotations

import os
import shutil
from pathlib import Path


WINDOWS = os.name == "nt"


def proxy_environment(environment: dict[str, str], default_no_proxy: str, *, env_file: Path | None = None) -> dict[str, str]:
    """Preserve inherited proxies without Windows case-colliding empty keys."""
    environment = dict(environment)
    if env_file is not None and not any(key.lower() == "easel_proxy" for key in environment):
        try:
            proxy = ""
            for line in env_file.read_text(encoding="utf-8-sig").splitlines():
                key, separator, value = line.strip().partition("=")
                if separator and key.strip() == "EASEL_PROXY":
                    proxy = value.strip().strip("\"'")
            if proxy:
                environment["EASEL_PROXY"] = proxy
        except (OSError, UnicodeError):
            pass
    result = dict(environment)

    def keys_for(name: str) -> list[str]:
        keys = sorted((key for key in environment if key.lower() == name),
                      key=lambda key: (key != name, key != name.upper(), key))
        return keys

    fallback = next((environment[key] for key in keys_for("easel_proxy")
                     if environment[key].strip()), "")
    for name in ("http_proxy", "https_proxy", "all_proxy", "no_proxy"):
        keys = keys_for(name)
        if keys:
            if not WINDOWS:
                # Unix permits distinct aliases and explicit empty overrides.
                if name == "no_proxy" and name not in result:
                    result[name] = environment[keys[0]]
                continue
            value = next((environment[key] for key in keys if environment[key].strip()),
                         environment[keys[0]])
            for key in keys:
                del result[key]
            # Keep lower-case keys for in-process consumers such as _wechat_env.
            result[name] = value
        elif name == "no_proxy":
            result[name] = default_no_proxy
        elif name != "all_proxy" and fallback:
            result[name] = fallback
    return result


def _version_directories(root: Path, pattern: str) -> list[Path]:
    versions = []
    try:
        for directory in root.glob(pattern):
            version_name = next((part for part in reversed(directory.parts) if part.startswith("v")), "")
            parts = version_name[1:].split(".")
            if len(parts) == 3 and all(part.isdigit() for part in parts):
                versions.append((tuple(int(part) for part in parts), directory))
    except OSError:
        return []
    return [directory for version, directory in sorted(versions, reverse=True)]


def _installation_directories(environment: dict[str, str], home: Path) -> list[Path]:
    from easel.openclaw_cmd import _npmrc_prefix

    directories = []
    prefixes = []
    for variable in ("EASEL_NPM_GLOBAL_PREFIX", "npm_config_prefix", "NPM_CONFIG_PREFIX"):
        if environment.get(variable):
            prefixes.append(Path(environment[variable]).expanduser())
    user_config = environment.get("NPM_CONFIG_USERCONFIG") or environment.get("npm_config_userconfig")
    configs = [Path(__file__).resolve().parents[1] / ".npmrc",
               Path(user_config).expanduser() if user_config else home / ".npmrc"]
    for config in configs:
        prefix = _npmrc_prefix(config)
        if prefix is not None:
            prefixes.append(prefix if prefix.is_absolute() else config.parent / prefix)
    prefixes.append(home / ".npm-global")
    directories.extend(prefix if WINDOWS else prefix / "bin" for prefix in prefixes)
    directories.extend([home / ".local" / "bin", home / ".opencode" / "bin",
                        Path(environment.get("VOLTA_HOME") or home / ".volta").expanduser() / "bin"])
    if WINDOWS:
        appdata = Path(environment.get("APPDATA") or home / "AppData" / "Roaming")
        local = Path(environment.get("LOCALAPPDATA") or home / "AppData" / "Local")
        directories.extend([appdata / "npm", local / "Programs" / "nodejs"])
        for variable in ("NVM_SYMLINK", "NVM_HOME"):
            if environment.get(variable):
                directories.append(Path(environment[variable]).expanduser())
        if environment.get("NVM_HOME"):
            directories.extend(_version_directories(Path(environment["NVM_HOME"]).expanduser(), "v*"))
        if environment.get("ProgramFiles"):
            directories.append(Path(environment["ProgramFiles"]) / "nodejs")
    else:
        nvm_root = Path(environment.get("NVM_DIR") or home / ".nvm").expanduser()
        directories.extend(_version_directories(nvm_root / "versions" / "node", "v*/bin"))
        if environment.get("NVM_BIN"):
            directories.append(Path(environment["NVM_BIN"]).expanduser())
        if environment.get("FNM_MULTISHELL_PATH"):
            directories.append(Path(environment["FNM_MULTISHELL_PATH"]).expanduser() / "bin")
        fnm_roots = [Path(environment["FNM_DIR"]).expanduser()] if environment.get("FNM_DIR") else [
            Path(environment.get("XDG_DATA_HOME") or home / ".local" / "share") / "fnm",
            home / "Library" / "Application Support" / "fnm",
        ]
        for root in fnm_roots:
            directories.extend(_version_directories(root / "node-versions", "v*/installation/bin"))
        brew = Path(environment.get("HOMEBREW_PREFIX") or "/opt/homebrew")
        directories.extend([brew / "opt" / "node@24" / "bin", brew / "opt" / "node@22" / "bin",
                            brew / "opt" / "node" / "bin", brew / "bin", Path("/usr/local/bin"), Path("/usr/bin")])
    return directories


def _prepend_vendor_path(result: dict[str, str], path_key: str) -> dict[str, str]:
    """Put EASEL_VENDOR_ROOT bin dirs first so bundled tools win over system PATH."""
    from easel.vendor_paths import vendor_bin_dirs, vendor_root

    root = vendor_root(result)
    if root is None:
        return result
    bins = vendor_bin_dirs(root)
    if not bins:
        return result
    separator = ";" if WINDOWS else os.pathsep
    current_path = result.get(path_key, os.defpath)
    seen = {os.path.normcase(directory) for directory in current_path.split(separator) if directory}
    prefixes: list[str] = []
    for directory in bins:
        key = os.path.normcase(str(directory))
        if key in seen:
            continue
        seen.add(key)
        prefixes.append(str(directory))
    if prefixes:
        result[path_key] = separator.join([*prefixes, current_path]) if current_path else separator.join(prefixes)
    result.setdefault("EASEL_VENDOR_ROOT", str(root))
    return result


def apply_private_tmpdir(environment: dict[str, str]) -> dict[str, str]:
    """Point OpenClaw temp/cache into the app data sandbox.

    On macOS OpenClaw's SQLite snapshot staging resolves to
    ``$XDG_CACHE_HOME/openclaw`` (preferred) then ``$XDG_CACHE_HOME/openclaw-<uid>``.
    Without ``XDG_CACHE_HOME`` it hardcodes ``~/Library/Caches``, which is often
    EPERM under Flutter / IDE hosts. Also pin ``TMPDIR`` for other fallbacks.
    """
    result = dict(environment)
    explicit_tmp = (result.get("EASEL_TMPDIR") or "").strip()
    explicit_cache = (result.get("EASEL_CACHE_DIR") or "").strip()
    data = (result.get("EASEL_DATA_DIR") or "").strip()
    state = (result.get("EASEL_OPENCLAW_STATE_DIR") or "").strip()
    if not (explicit_tmp or explicit_cache or data or state):
        return result

    root = Path(data).expanduser() if data else (
        Path(state).expanduser() if state else None)
    tmp_base = Path(explicit_tmp).expanduser() if explicit_tmp else (
        (root / "tmp") if root is not None else None)
    cache_base = Path(explicit_cache).expanduser() if explicit_cache else (
        (root / "cache") if root is not None else tmp_base)

    def _prepare(directory: Path | None) -> str | None:
        if directory is None:
            return None
        try:
            directory.mkdir(parents=True, exist_ok=True)
            try:
                os.chmod(directory, 0o700)
            except OSError:
                pass
            uid = os.getuid() if hasattr(os, "getuid") else None
            # OpenClaw preferred: <cache>/openclaw ; fallback: <cache>/openclaw-<uid>
            for name in ("openclaw", *( [f"openclaw-{uid}"] if uid is not None else [])):
                scoped = directory / name
                scoped.mkdir(parents=True, exist_ok=True)
                try:
                    os.chmod(scoped, 0o700)
                except OSError:
                    pass
            return str(directory)
        except OSError:
            return None

    tmp_path = _prepare(tmp_base)
    cache_path = _prepare(cache_base) or tmp_path
    if tmp_path:
        result["EASEL_TMPDIR"] = tmp_path
        result["TMPDIR"] = tmp_path
        result["TMP"] = tmp_path
        result["TEMP"] = tmp_path
    if cache_path:
        result["EASEL_CACHE_DIR"] = cache_path
        result["XDG_CACHE_HOME"] = cache_path
    return result


def web_environment(environment: dict[str, str]) -> dict[str, str]:
    """Find user-installed Agent CLIs when a non-interactive launcher loses PATH."""
    result = apply_private_tmpdir(environment)
    path_key = next((key for key in result if key.upper() == "PATH"), "PATH") if WINDOWS else "PATH"
    result = _prepend_vendor_path(result, path_key)
    current_path = result.get(path_key, os.defpath)
    missing = {command for command in ("openclaw", "opencode", "codex", "node", "ffmpeg")
               if shutil.which(command, path=current_path) is None}
    if not missing:
        return result
    try:
        directories = _installation_directories(result, Path.home())
    except (OSError, RuntimeError):
        return result
    separator = ";" if WINDOWS else os.pathsep
    seen = {os.path.normcase(directory) for directory in current_path.split(separator)}
    additions = []
    for directory in directories:
        if os.path.normcase(str(directory)) in seen:
            continue
        seen.add(os.path.normcase(str(directory)))
        found = {command for command in missing
                 if shutil.which(command, path=str(directory)) is not None}
        if not found:
            continue
        additions.append(str(directory))
        missing -= found
        if not missing:
            break
    if additions:
        result[path_key] = separator.join([current_path, *additions])
    return result
