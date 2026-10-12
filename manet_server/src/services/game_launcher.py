"""
Starts a registered game and notices when it ends.

Executables are started directly and their whole process tree is tracked.
Shortcuts/URLs (.lnk, .url, steam://) go through the shell and cannot be
tracked; the same happens when a launcher exits right away and hands off to
another process (common with Steam/Epic). Those games end only when the host
says so.
"""
import asyncio
import logging
import os
import subprocess
import time

import psutil

LOG = logging.getLogger(__name__)

# A tracked launch that ends faster than this most likely handed off to a
# launcher/store process; treat it as untracked instead of "game closed".
HANDOFF_WINDOW_SECONDS = 10.0
POLL_INTERVAL_SECONDS = 1.0

_DETACHED = 0x00000008 | 0x00000200  # DETACHED_PROCESS | CREATE_NEW_PROCESS_GROUP


class LaunchError(Exception):
    pass


class RunningGame:
    def __init__(self, game: dict, process: subprocess.Popen | None):
        self.game = game
        self.process = process
        self.started_at = time.monotonic()
        self.tracked = process is not None
        self._pids: set[int] = {process.pid} if process else set()

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
            except (psutil.NoSuchProcess, psutil.AccessDenied):
                continue
        self._pids |= alive
        return alive

    def kill(self):
        for pid in self.alive_pids():
            try:
                psutil.Process(pid).kill()
            except (psutil.NoSuchProcess, psutil.AccessDenied):
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
            LOG.error("Failed to start %s: %s", path, e)
            raise LaunchError("start_failed") from e
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
