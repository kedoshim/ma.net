""""Play online": a Cloudflare quick tunnel to this server.

cloudflared makes an outbound connection to Cloudflare and gets a random
https://<words>.trycloudflare.com address that forwards to the local port,
so phones anywhere can reach the host without port forwarding, an account
or a server of our own.

The process is put in a Windows job object that kills it when the server
process goes away, however that happens (the server often leaves through
os._exit, which skips every cleanup hook).
"""

import asyncio
import ctypes
import logging
import os
import re
import shutil
import subprocess
import sys
from pathlib import Path

import aiohttp

LOG = logging.getLogger("tunnel")

STATE_OFF = "off"
STATE_STARTING = "starting"
STATE_VERIFYING = "verifying"
STATE_ONLINE = "online"
STATE_ERROR = "error"

_URL_PATTERN = re.compile(r"https://[a-z0-9-]+\.trycloudflare\.com")
_URL_TIMEOUT_SECONDS = 30.0
# A fresh quick tunnel's name usually resolves within 5-20 seconds.
_VERIFY_TIMEOUT_SECONDS = 60.0
_VERIFY_INTERVAL_SECONDS = 1.5
_MAX_RESTARTS = 3

# Asking the system resolver for the name before its record exists makes
# Windows cache the miss for minutes, so the self-test resolves through
# DNS-over-HTTPS and connects to the address directly.
_DOH_ENDPOINTS = (
    "https://cloudflare-dns.com/dns-query",
    "https://dns.google/resolve",
)

_CREATE_NO_WINDOW = 0x08000000


def resolve_cloudflared_path() -> str | None:
    candidates = []
    override = os.environ.get("MANET_CLOUDFLARED")
    if override:
        candidates.append(Path(override))
    if getattr(sys, "frozen", False):
        # Installed next to manet_network_service.exe.
        candidates.append(Path(sys.executable).parent / "cloudflared.exe")
    else:
        repo_root = Path(__file__).resolve().parents[3]
        candidates.append(repo_root / "install" / "tools" / "cloudflared.exe")
    for candidate in candidates:
        if candidate.is_file():
            return str(candidate)
    return shutil.which("cloudflared")


class _KillOnCloseJob:
    """Windows job object whose processes die with this process."""

    def __init__(self):
        self._handle = None
        if os.name != "nt":
            return
        try:
            kernel32 = ctypes.windll.kernel32
            handle = kernel32.CreateJobObjectW(None, None)
            if not handle:
                return

            class _BasicLimits(ctypes.Structure):
                _fields_ = [
                    ("PerProcessUserTimeLimit", ctypes.c_int64),
                    ("PerJobUserTimeLimit", ctypes.c_int64),
                    ("LimitFlags", ctypes.c_uint32),
                    ("MinimumWorkingSetSize", ctypes.c_size_t),
                    ("MaximumWorkingSetSize", ctypes.c_size_t),
                    ("ActiveProcessLimit", ctypes.c_uint32),
                    ("Affinity", ctypes.c_size_t),
                    ("PriorityClass", ctypes.c_uint32),
                    ("SchedulingClass", ctypes.c_uint32),
                ]

            class _IoCounters(ctypes.Structure):
                _fields_ = [(name, ctypes.c_uint64) for name in (
                    "ReadOperationCount", "WriteOperationCount", "OtherOperationCount",
                    "ReadTransferCount", "WriteTransferCount", "OtherTransferCount",
                )]

            class _ExtendedLimits(ctypes.Structure):
                _fields_ = [
                    ("BasicLimitInformation", _BasicLimits),
                    ("IoInfo", _IoCounters),
                    ("ProcessMemoryLimit", ctypes.c_size_t),
                    ("JobMemoryLimit", ctypes.c_size_t),
                    ("PeakProcessMemoryUsed", ctypes.c_size_t),
                    ("PeakJobMemoryUsed", ctypes.c_size_t),
                ]

            info = _ExtendedLimits()
            info.BasicLimitInformation.LimitFlags = 0x2000  # KILL_ON_JOB_CLOSE
            ok = kernel32.SetInformationJobObject(
                handle, 9, ctypes.byref(info), ctypes.sizeof(info)  # ExtendedLimitInformation
            )
            if ok:
                self._handle = handle
            else:
                kernel32.CloseHandle(handle)
        except Exception:
            LOG.exception("Could not create the tunnel job object")

    def assign(self, pid: int):
        if self._handle is None:
            return
        kernel32 = ctypes.windll.kernel32
        process = kernel32.OpenProcess(0x0001 | 0x0100, False, pid)  # TERMINATE | SET_QUOTA
        if not process:
            return
        try:
            if not kernel32.AssignProcessToJobObject(self._handle, process):
                LOG.warning("Could not tie cloudflared (pid %s) to the server's lifetime", pid)
        finally:
            kernel32.CloseHandle(process)


class TunnelService:
    def __init__(self, port: int, on_change=None):
        self.port = port
        self._on_change = on_change
        self.state = STATE_OFF
        self.url: str | None = None
        self.error: str | None = None
        self._process: asyncio.subprocess.Process | None = None
        self._runner: asyncio.Task | None = None
        self._job = _KillOnCloseJob()

    def snapshot(self) -> dict:
        return {"state": self.state, "url": self.url, "error": self.error}

    def start(self):
        if self._runner is not None and not self._runner.done():
            return
        self._set(STATE_STARTING, url=None, error=None)
        self._runner = asyncio.create_task(self._run())

    async def stop(self):
        runner, self._runner = self._runner, None
        if runner is not None:
            runner.cancel()
            try:
                await runner
            except asyncio.CancelledError:
                pass
        await self._kill_process()
        self._set(STATE_OFF, url=None, error=None)

    def _set(self, state, *, url=..., error=...):
        self.state = state
        if url is not ...:
            self.url = url
        if error is not ...:
            self.error = error
        LOG.info("Tunnel %s%s", state, f" ({self.url})" if state == STATE_ONLINE else "")
        if self._on_change is not None:
            try:
                self._on_change(self.snapshot())
            except Exception:
                LOG.exception("Tunnel state listener failed")

    async def _run(self):
        executable = resolve_cloudflared_path()
        if executable is None:
            self._set(STATE_ERROR, url=None, error="cloudflared_missing")
            return

        restarts = 0
        while True:
            self._set(STATE_STARTING, url=None, error=None)
            try:
                url = await self._launch(executable)
                self._set(STATE_VERIFYING, url=url)
                await self._verify(url)
                self._set(STATE_ONLINE)
                restarts = 0
                code = await self._process.wait()
                LOG.warning("cloudflared exited with code %s", code)
            except asyncio.CancelledError:
                raise
            except TunnelError as exc:
                LOG.warning("Tunnel failed: %s", exc.code)
                await self._kill_process()
                if restarts >= _MAX_RESTARTS:
                    self._set(STATE_ERROR, url=None, error=exc.code)
                    return
            except Exception:
                LOG.exception("Tunnel crashed")
                await self._kill_process()
                if restarts >= _MAX_RESTARTS:
                    self._set(STATE_ERROR, url=None, error="unknown")
                    return
            restarts += 1
            await asyncio.sleep(2 ** restarts)

    async def _launch(self, executable: str) -> str:
        self._process = await asyncio.create_subprocess_exec(
            executable,
            "tunnel",
            "--no-autoupdate",
            "--url",
            f"http://127.0.0.1:{self.port}",
            stdin=subprocess.DEVNULL,
            stdout=subprocess.DEVNULL,
            stderr=subprocess.PIPE,
            creationflags=_CREATE_NO_WINDOW if os.name == "nt" else 0,
        )
        self._job.assign(self._process.pid)

        url_found: asyncio.Future = asyncio.get_running_loop().create_future()
        asyncio.create_task(self._pump_output(self._process, url_found))
        try:
            return await asyncio.wait_for(url_found, _URL_TIMEOUT_SECONDS)
        except asyncio.TimeoutError:
            raise TunnelError("no_url")

    async def _pump_output(self, process, url_found: asyncio.Future):
        """Reads cloudflared's log until it exits (an unread pipe would
        eventually block it) and picks the public address out of it."""
        assert process.stderr is not None
        async for raw in process.stderr:
            line = raw.decode("utf-8", errors="replace").rstrip()
            LOG.debug("cloudflared: %s", line)
            if not url_found.done():
                match = _URL_PATTERN.search(line)
                if match:
                    url_found.set_result(match.group(0))
        if not url_found.done():
            url_found.set_exception(TunnelError("exited"))

    async def _verify(self, url: str):
        """The tunnel is only announced once its name resolves publicly and
        a request through it reaches this server."""
        host = url.removeprefix("https://")
        loop = asyncio.get_running_loop()
        deadline = loop.time() + _VERIFY_TIMEOUT_SECONDS
        timeout = aiohttp.ClientTimeout(total=5)
        async with aiohttp.ClientSession(timeout=timeout) as session:
            while loop.time() < deadline:
                if self._process is None or self._process.returncode is not None:
                    raise TunnelError("exited")
                try:
                    ip = await _resolve_public(session, host)
                    if ip is not None:
                        async with session.get(
                            f"https://{ip}/api/server/status",
                            headers={"Host": host},
                            server_hostname=host,
                        ) as resp:
                            if resp.status == 200:
                                return
                except (aiohttp.ClientError, asyncio.TimeoutError, ValueError):
                    pass
                await asyncio.sleep(_VERIFY_INTERVAL_SECONDS)
        raise TunnelError("unreachable")

    async def _kill_process(self):
        process, self._process = self._process, None
        if process is None or process.returncode is not None:
            return
        try:
            process.kill()
            await asyncio.wait_for(process.wait(), 5)
        except (ProcessLookupError, asyncio.TimeoutError):
            pass


async def _resolve_public(session: aiohttp.ClientSession, host: str) -> str | None:
    for endpoint in _DOH_ENDPOINTS:
        try:
            async with session.get(
                endpoint,
                params={"name": host, "type": "A"},
                headers={"Accept": "application/dns-json"},
            ) as resp:
                data = await resp.json(content_type=None)
        except (aiohttp.ClientError, asyncio.TimeoutError, ValueError):
            continue
        # Resolvers pick up a new name at different moments: ask each one.
        for answer in data.get("Answer") or ():
            if answer.get("type") == 1:  # A record
                return answer.get("data")
    return None


class TunnelError(Exception):
    def __init__(self, code: str):
        super().__init__(code)
        self.code = code
