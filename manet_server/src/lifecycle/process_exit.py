"""
How the server process ends. The desktop app owns the server: when the app
asks it to stop, or the app process dies for any reason (closed, crashed,
`flutter run` stopped), the server unplugs its virtual gamepads and exits
by itself instead of lingering as an orphan.
"""
import asyncio
import ctypes
import logging
import os
import sys
import threading

from src.core.logging_config import stop_logging

LOG = logging.getLogger(__name__)

_SYNCHRONIZE = 0x00100000
_INFINITE = 0xFFFFFFFF
_CLEANUP_TIMEOUT_SECONDS = 2.0

_exiting = threading.Lock()


def _hard_exit(code: int = 0):
    stop_logging()
    os._exit(code)


async def _release_gamepads(manager):
    async with manager._slot_lock:
        manager.cleanup_gamepads()


def exit_process(manager, loop, reason: str):
    """Release the gamepads on the event loop, then end the process.
    Safe to call from any thread, and more than once."""
    if not _exiting.acquire(blocking=False):
        return
    LOG.info("Exiting server: %s", reason)
    try:
        if loop is not None and loop.is_running():
            on_loop = False
            try:
                on_loop = asyncio.get_running_loop() is loop
            except RuntimeError:
                pass
            if on_loop:
                # Called from a handler: finish cleanup in a task and leave
                # once it completes, so the HTTP response can still go out.
                task = loop.create_task(_release_gamepads(manager))
                task.add_done_callback(lambda _: loop.call_later(0.05, _hard_exit))
                loop.call_later(_CLEANUP_TIMEOUT_SECONDS, _hard_exit)
                return
            future = asyncio.run_coroutine_threadsafe(_release_gamepads(manager), loop)
            future.result(timeout=_CLEANUP_TIMEOUT_SECONDS)
    except Exception:
        LOG.exception("Gamepad cleanup before exit failed")
    _hard_exit()


def watch_parent(pid: int, manager, loop):
    """Exit when process `pid` (the desktop app) ends."""
    if sys.platform != "win32":
        return

    def wait_for_parent():
        kernel32 = ctypes.WinDLL("kernel32", use_last_error=True)
        kernel32.OpenProcess.restype = ctypes.c_void_p
        kernel32.OpenProcess.argtypes = [ctypes.c_uint32, ctypes.c_int, ctypes.c_uint32]
        kernel32.WaitForSingleObject.argtypes = [ctypes.c_void_p, ctypes.c_uint32]
        handle = kernel32.OpenProcess(_SYNCHRONIZE, False, pid)
        if not handle:
            exit_process(manager, loop, f"parent process {pid} is not running")
            return
        kernel32.WaitForSingleObject(handle, _INFINITE)
        exit_process(manager, loop, f"parent process {pid} ended")

    LOG.info("Watching parent process %d", pid)
    threading.Thread(target=wait_for_parent, name="parent-watch", daemon=True).start()
