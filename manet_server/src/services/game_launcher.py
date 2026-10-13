"""
Starts a registered game and notices when it ends.

Executables are started directly and their whole process tree is tracked.
Shortcuts/URLs (.lnk, .url, steam://) go through the shell and cannot be
tracked; the same happens when a launcher exits right away and hands off to
another process (common with Steam/Epic). Those games end only when the host
says so.
"""
import asyncio
import ctypes
import logging
import os
import subprocess
import time
from ctypes import wintypes

import psutil

LOG = logging.getLogger(__name__)

# A tracked launch that ends faster than this most likely handed off to a
# launcher/store process; treat it as untracked instead of "game closed".
HANDOFF_WINDOW_SECONDS = 10.0
POLL_INTERVAL_SECONDS = 1.0

_DETACHED = 0x00000008 | 0x00000200  # DETACHED_PROCESS | CREATE_NEW_PROCESS_GROUP

_ERROR_ELEVATION_REQUIRED = 740
_ERROR_CANCELLED = 1223  # user said "No" on the UAC prompt
_SEE_MASK_NOCLOSEPROCESS = 0x00000040
_SEE_MASK_NOASYNC = 0x00000100
_SEE_MASK_FLAG_NO_UI = 0x00000400  # no shell error dialogs; UAC still shows
_SW_SHOWNORMAL = 1


class LaunchError(Exception):
    pass


class _ShellExecuteInfo(ctypes.Structure):
    _fields_ = [
        ("cbSize", wintypes.DWORD),
        ("fMask", ctypes.c_ulong),
        ("hwnd", wintypes.HWND),
        ("lpVerb", wintypes.LPCWSTR),
        ("lpFile", wintypes.LPCWSTR),
        ("lpParameters", wintypes.LPCWSTR),
        ("lpDirectory", wintypes.LPCWSTR),
        ("nShow", ctypes.c_int),
        ("hInstApp", wintypes.HINSTANCE),
        ("lpIDList", ctypes.c_void_p),
        ("lpClass", wintypes.LPCWSTR),
        ("hkeyClass", wintypes.HKEY),
        ("dwHotKey", wintypes.DWORD),
        ("hIconOrMonitor", wintypes.HANDLE),
        ("hProcess", wintypes.HANDLE),
    ]


def _start_elevated(path: str, arguments: str, cwd: str | None) -> int:
    """Starts `path` as admin through the shell and returns its pid."""
    info = _ShellExecuteInfo()
    info.cbSize = ctypes.sizeof(info)
    info.fMask = _SEE_MASK_NOCLOSEPROCESS | _SEE_MASK_NOASYNC | _SEE_MASK_FLAG_NO_UI
    info.lpVerb = "runas"
    info.lpFile = path
    info.lpParameters = arguments or None
    info.lpDirectory = cwd or None
    info.nShow = _SW_SHOWNORMAL

    shell32 = ctypes.WinDLL("shell32", use_last_error=True)
    kernel32 = ctypes.WinDLL("kernel32", use_last_error=True)
    shell32.ShellExecuteExW.argtypes = [ctypes.POINTER(_ShellExecuteInfo)]
    shell32.ShellExecuteExW.restype = wintypes.BOOL
    kernel32.GetProcessId.argtypes = [wintypes.HANDLE]
    kernel32.GetProcessId.restype = wintypes.DWORD
    kernel32.CloseHandle.argtypes = [wintypes.HANDLE]

    if not shell32.ShellExecuteExW(ctypes.byref(info)):
        error = ctypes.get_last_error()
        if error == _ERROR_CANCELLED:
            LOG.info("Host declined the admin prompt for %s", path)
            raise LaunchError("elevation_cancelled")
        LOG.error("Failed to start %s elevated: %s", path, ctypes.FormatError(error))
        raise LaunchError("start_failed")
    if not info.hProcess:
        raise LaunchError("start_failed")
    try:
        return kernel32.GetProcessId(info.hProcess)
    finally:
        kernel32.CloseHandle(info.hProcess)


class RunningGame:
    def __init__(self, game: dict, process: subprocess.Popen | None, pid: int | None = None):
        self.game = game
        self.process = process
        self.started_at = time.monotonic()
        root_pid = process.pid if process else pid
        self.tracked = root_pid is not None
        self._pids: set[int] = {root_pid} if root_pid is not None else set()

    def to_payload(self) -> dict:
        return {"id": self.game["id"], "name": self.game["name"], "tracked": self.tracked}

    def alive_pids(self) -> set[int]:
        """Tracked processes still running, including newly spawned children."""
        alive = set()
        for pid in list(self._pids):
            try:
                proc = psutil.Process(pid)
                if proc.status() == psutil.STATUS_ZOMBIE:
                    continue
                alive.add(pid)
                alive.update(child.pid for child in proc.children(recursive=True))
            except psutil.AccessDenied:
                # Elevated games can't be fully inspected, but they still exist.
                alive.add(pid)
            except psutil.NoSuchProcess:
                continue
        self._pids |= alive
        return alive

    def kill(self):
        for pid in self.alive_pids():
            try:
                psutil.Process(pid).kill()
            except psutil.AccessDenied:
                LOG.warning("Cannot close elevated process %d without admin rights", pid)
            except psutil.NoSuchProcess:
                pass


def start_game(game: dict) -> RunningGame:
    path = game["path"]
    is_uri = "://" in path
    if not is_uri and not os.path.exists(path):
        raise LaunchError("path_not_found")

    if not is_uri and path.lower().endswith(".exe"):
        cwd = game.get("workingDirectory") or os.path.dirname(path)
        try:
            # Windows parses the command line itself; passing the user's
            # argument string through untouched keeps their quoting intact.
            command_line = f'"{path}" {game.get("arguments", "")}'.strip()
            process = subprocess.Popen(
                command_line,
                cwd=cwd or None,
                creationflags=_DETACHED,
                close_fds=True,
            )
        except OSError as e:
            if getattr(e, "winerror", None) != _ERROR_ELEVATION_REQUIRED:
                LOG.error("Failed to start %s: %s", path, e)
                raise LaunchError("start_failed") from e
            # The exe's manifest asks for admin; CreateProcess can't do that,
            # the shell can (the host sees a UAC prompt).
            pid = _start_elevated(path, game.get("arguments", ""), cwd)
            LOG.info("Started game %s elevated (pid %d)", game["name"], pid)
            return RunningGame(game, None, pid=pid)
        LOG.info("Started game %s (pid %d)", game["name"], process.pid)
        return RunningGame(game, process)

    try:
        os.startfile(path)  # .lnk, .url, steam:// ...
    except OSError as e:
        LOG.error("Failed to open %s: %s", path, e)
        raise LaunchError("start_failed") from e
    LOG.info("Opened game %s via shell (untracked)", game["name"])
    return RunningGame(game, None)


async def watch_game(running: RunningGame, on_exit):
    """Calls `on_exit()` when a tracked game's processes are all gone."""
    if not running.tracked:
        return
    while True:
        await asyncio.sleep(POLL_INTERVAL_SECONDS)
        alive = await asyncio.to_thread(running.alive_pids)
        if alive:
            continue
        if time.monotonic() - running.started_at < HANDOFF_WINDOW_SECONDS:
            LOG.info("Game %s handed off to another process; no longer tracked", running.game["name"])
            running.tracked = False
            on_exit(handoff=True)
            return
        LOG.info("Game %s exited", running.game["name"])
        on_exit(handoff=False)
        return
