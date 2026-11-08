"""Compare and copy repository-owned skill files without touching workspace memories."""
from __future__ import annotations

import base64
import hashlib
import os
import shutil
import subprocess
import tempfile
from pathlib import Path

from easel.openclaw_workspace import workspace_dir

SOURCE_DIRS = ('skills/builtin', 'skills/shared')
WORKSPACE_LINKS = {'easel-profiles': 'profiles', 'outputs': 'outputs'}
WINDOWS = os.name == 'nt'
_IGNORED_DIRS = {'__pycache__', '.git', '.venv', 'node_modules', '.pytest_cache'}


def project_root() -> Path:
    """Prefer EASEL_ROOT (Flutter/packaged sidecar) over the installed package path."""
    raw = (os.environ.get('EASEL_ROOT') or '').strip()
    if raw:
        return Path(raw).expanduser().resolve()
    return Path(__file__).resolve().parents[1]


# Back-compat for importers / tests that read the module attribute.
PROJECT_ROOT = project_root()


def agent_workspace() -> Path:
    override = os.environ.get('EASEL_OPENCLAW_WORKSPACE')
    return Path(override).expanduser() if override else workspace_dir()


def _files(root: Path):
    for entry in sorted(root.iterdir()):
        if entry.name in _IGNORED_DIRS or entry.name == '.DS_Store' or entry.suffix in {'.pyc', '.pyo'}:
            continue
        if entry.is_symlink():
            raise ValueError('仓库源文件包含链接，无法安全校验')
        if entry.is_dir():
            yield from _files(entry)
        elif entry.is_file():
            yield entry


def _digest(path: Path) -> bytes:
    digest = hashlib.sha256()
    with path.open('rb') as source:
        for chunk in iter(lambda: source.read(1024 * 1024), b''):
            digest.update(chunk)
    return digest.digest()


def _same_file(source: Path, destination: Path) -> bool:
    try:
        return source.samefile(destination)
    except OSError:
        return False


def _managed_files(ws: Path):
    root = project_root()
    boundary = ws.resolve()
    for relative in SOURCE_DIRS:
        source = (root / relative).resolve()
        if boundary == source or source in boundary.parents:
            raise ValueError('workspace 不能位于技能源目录内部')
    for relative, name in zip(SOURCE_DIRS, ('skills', 'shared')):
        source_root = root / relative
        if not source_root.is_dir():
            raise ValueError('仓库技能源目录不存在')
        for source in _files(source_root):
            destination = ws / name / source.relative_to(source_root)
            if not _same_file(source, destination) and boundary not in destination.resolve().parents:
                raise ValueError('workspace 技能目标链接到了其他目录，请先核对路径')
            yield source, destination


def _matches(source: Path, destination: Path) -> bool:
    return _same_file(source, destination) or (
        destination.is_file() and source.stat().st_size == destination.stat().st_size
        and _digest(source) == _digest(destination))


def skills_sync_state() -> tuple[bool, str]:
    ws = None
    try:
        ws = agent_workspace()
        skills = ws / 'skills'
        if not skills.is_dir() or not any(skills.iterdir()):
            return False, f'agent 实际读取的 workspace 是 {ws}，其中 skills/ 为空或不存在'
        count = 0
        for source, destination in _managed_files(ws):
            count += 1
            if not _matches(source, destination):
                relative = source.relative_to(project_root())
                return False, f'仓库文件 {relative} 缺失或内容不同：改了但没同步；请运行 python scripts/sync_if_stale.py'
        if not count:
            return False, '仓库技能源为空，无法确认同步状态'
        return True, f'workspace 是 {ws}，{count} 个现有仓库文件已是最新；额外本机文件保留，不保证既有会话缓存已重载'
    except (OSError, ValueError, RuntimeError):
        return False, f'无法完整校验 workspace {ws} 的技能文件或路径，未确认同步'


def sync_needed() -> bool:
    return not skills_sync_state()[0]


def synchronize_skills() -> int:
    """Atomically replace only existing source paths; keep all user extras and memories."""
    root = project_root()
    ws = agent_workspace()
    if ws.resolve() == root.resolve():
        raise ValueError('workspace 不能是项目根目录')
    files = list(_managed_files(ws))  # Validate every destination before writing any file.
    copied = 0
    for source, destination in files:
        if _matches(source, destination):
            continue
        destination.parent.mkdir(parents=True, exist_ok=True)
        temporary = None
        try:
            with tempfile.NamedTemporaryFile(dir=destination.parent, prefix='.easel-sync-', delete=False) as file:
                temporary = Path(file.name)
            shutil.copy2(source, temporary)
            os.replace(temporary, destination)
            copied += 1
        finally:
            if temporary is not None:
                temporary.unlink(missing_ok=True)
    return copied


def _migrate_dir_contents(source: Path, destination: Path) -> int:
    """Copy missing top-level entries from an old outputs/profiles tree into the new one."""
    if not source.is_dir() or source.resolve() == destination.resolve():
        return 0
    moved = 0
    for child in source.iterdir():
        if child.name.startswith('.'):
            continue
        dest = destination / child.name
        if dest.exists() or dest.is_symlink():
            continue
        try:
            if child.is_dir():
                shutil.copytree(child, dest, symlinks=True)
            elif child.is_file():
                shutil.copy2(child, dest)
            else:
                continue
            moved += 1
        except OSError:
            continue
    return moved


def align_workspace_links() -> list[str]:
    """Point workspace ``outputs`` / ``easel-profiles`` at this EASEL_ROOT.

    Flutter 内容库读的是 ``$EASEL_ROOT/outputs``；OpenClaw agent 写的是
    ``workspace/outputs``。若后者仍软链到旧仓库（例如迁仓后的 Easel/outputs），
    skill 说写进了 outputs，内容库却是空的。
    """
    root = project_root()
    ws = agent_workspace()
    notes: list[str] = []
    for name, relative in WORKSPACE_LINKS.items():
        target = root / relative
        try:
            target.mkdir(parents=True, exist_ok=True)
        except OSError as exc:
            notes.append(f'{name}: 无法创建目标目录 {target}（{exc}）')
            continue
        target = target.resolve()
        link = ws / name
        try:
            if link.is_symlink():
                try:
                    current = link.resolve()
                except OSError:
                    current = None
                if current == target:
                    continue
                old = current
                link.unlink()
                if old is not None:
                    migrated = _migrate_dir_contents(old, target)
                    if migrated:
                        notes.append(f'{name}: 已从旧目录迁入 {migrated} 项 → {target}')
                link.symlink_to(target, target_is_directory=True)
                notes.append(f'{name}: 已改链 → {target}')
                continue
            if link.exists():
                if _same_file(link, target):
                    continue
                notes.append(f'{name}: 已有真实目录且与项目源不同，已保留 {link}')
                continue
            link.symlink_to(target, target_is_directory=True)
            notes.append(f'{name}: 已创建链接 → {target}')
        except OSError as exc:
            notes.append(f'{name}: 无法对齐链接（{exc}）')
    return notes


def ensure_workspace_links() -> list[str]:
    """Create missing Windows junctions; never delete or replace an existing copy/link."""
    if not WINDOWS:
        # POSIX: repair/create symlinks so Flutter 内容库与 agent 写入口一致。
        return align_workspace_links()
    root = project_root()
    ws = agent_workspace()
    problems = []
    for name, relative in WORKSPACE_LINKS.items():
        link, target = ws / name, root / relative
        if not target.is_dir() or _same_file(link, target):
            continue
        if os.path.lexists(link):
            problems.append(f'{name} 已有目录或链接与项目源不同，已保留，请人工核对后处理')
            continue
        executable = shutil.which('powershell') or shutil.which('pwsh')
        if not executable:
            problems.append(f'{name} 缺少 PowerShell，无法建立目录联接')
            continue
        quote = lambda value: "'" + str(value).replace("'", "''") + "'"
        script = "$ErrorActionPreference='Stop'; New-Item -ItemType Junction -Path " + quote(link) + ' -Value ' + quote(target) + ' | Out-Null'
        encoded = base64.b64encode(script.encode('utf-16-le')).decode('ascii')
        try:
            result = subprocess.run([executable, '-NoProfile', '-NonInteractive', '-EncodedCommand', encoded],
                                    capture_output=True, text=True, encoding='utf-8', errors='replace', timeout=30)
            if result.returncode != 0 or not _same_file(link, target):
                problems.append(f'{name} 无法建立目录联接，既有目录未改动')
        except (OSError, subprocess.SubprocessError):
            problems.append(f'{name} 无法建立目录联接，既有目录未改动')
    return problems
