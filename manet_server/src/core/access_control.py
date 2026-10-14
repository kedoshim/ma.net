"""Who may join: open, room password or the host's approval.

The rule is set separately for phones on the local network and phones
coming through the "Play online" tunnel. A phone let in once stays in for
the rest of the server's life, so a Wi-Fi hiccup or a change of rule never
asks it again; kicking takes that away. Bans last until the server stops.
"""

import asyncio
import logging
import time
from dataclasses import dataclass, field

LOG = logging.getLogger("access")

MODE_OPEN = "open"
MODE_PASSWORD = "password"
MODE_APPROVAL = "approval"
MODES = (MODE_OPEN, MODE_PASSWORD, MODE_APPROVAL)

ADMITTED = "admitted"
BANNED = "banned"

MAX_PASSWORD_ATTEMPTS = 5
PASSWORD_LOCKOUT_SECONDS = 60.0


@dataclass
class PendingRequest:
    device_id: str
    name: str
    origin: str
    identity: dict
    since: float = field(default_factory=time.time)
    decision: asyncio.Future | None = None

    def to_payload(self) -> dict:
        return {
            "deviceId": self.device_id,
            "name": self.name,
            "origin": self.origin,
            "since": self.since,
            **self.identity,
        }


class AccessGate:
    def __init__(self, on_change=None):
        self._on_change = on_change
        self.modes = {"lan": MODE_OPEN, "online": MODE_APPROVAL}
        self.password = ""
        self.admitted: set[str] = set()
        self.pending: dict[str, PendingRequest] = {}
        self.banned_devices: set[str] = set()
        self.banned_ips: set[str] = set()
        self._ips: dict[str, str] = {}
        # Wrong passwords per device and per address: (count, locked_until).
        self._failures: dict[str, tuple[int, float]] = {}

    # Settings

    def configure(self, lan=None, online=None, password=None):
        if lan in MODES:
            self.modes["lan"] = lan
        if online in MODES:
            self.modes["online"] = online
        if password is not None:
            self.password = str(password).strip()[:64]
        self._changed()

    def mode_for(self, origin: str) -> str:
        mode = self.modes.get(origin, MODE_APPROVAL)
        if mode == MODE_PASSWORD and not self.password:
            # A password rule without a password would lock everyone out.
            return MODE_APPROVAL
        return mode

    # Joining

    def check(self, device_id: str, origin: str, ip: str | None) -> str:
        """ADMITTED, BANNED, or the mode the phone has to go through."""
        if ip:
            self._ips[device_id] = ip
        if device_id in self.banned_devices or (ip and ip in self.banned_ips):
            return BANNED
        if device_id in self.admitted:
            return ADMITTED
        mode = self.mode_for(origin)
        if mode == MODE_OPEN:
            self.admitted.add(device_id)
            return ADMITTED
        return mode

    def try_password(self, device_id: str, ip: str | None, password) -> tuple[str, int]:
        """("ok" | "wrong" | "locked", attempts left)."""
        keys = [f"device:{device_id}"] + ([f"ip:{ip}"] if ip else [])
        now = time.monotonic()
        for key in keys:
            count, until = self._failures.get(key, (0, 0.0))
            if until > now:
                return "locked", 0
            if until and until <= now:
                self._failures.pop(key, None)
        if self.password and str(password or "") == self.password:
            for key in keys:
                self._failures.pop(key, None)
            self.admitted.add(device_id)
            return "ok", MAX_PASSWORD_ATTEMPTS
        worst = 0
        for key in keys:
            count = self._failures.get(key, (0, 0.0))[0] + 1
            until = now + PASSWORD_LOCKOUT_SECONDS if count >= MAX_PASSWORD_ATTEMPTS else 0.0
            self._failures[key] = (0 if until else count, until)
            worst = max(worst, MAX_PASSWORD_ATTEMPTS if until else count)
        left = MAX_PASSWORD_ATTEMPTS - worst
        return ("locked", 0) if left <= 0 else ("wrong", left)

    def request_approval(self, device_id: str, name: str, origin: str, identity: dict) -> asyncio.Future:
        """Queues the phone for the host; the future resolves to True/False."""
        previous = self.pending.pop(device_id, None)
        if previous is not None and previous.decision and not previous.decision.done():
            previous.decision.set_result(False)
        request = PendingRequest(
            device_id=device_id,
            name=name,
            origin=origin,
            identity=identity,
            decision=asyncio.get_running_loop().create_future(),
        )
        self.pending[device_id] = request
        LOG.info("Device %s (%s) asks to join from %s", device_id, name, origin)
        self._changed()
        return request.decision

    def answer(self, device_id: str, accept: bool, ban: bool = False) -> bool:
        request = self.pending.pop(device_id, None)
        if ban:
            self._ban(device_id)
        elif accept:
            self.admitted.add(device_id)
        if request is not None and request.decision and not request.decision.done():
            request.decision.set_result(accept and not ban)
        self._changed()
        return request is not None

    def withdraw(self, device_id: str):
        """The phone gave up or lost its connection while waiting."""
        request = self.pending.pop(device_id, None)
        if request is not None:
            if request.decision and not request.decision.done():
                request.decision.cancel()
            self._changed()

    def kick(self, device_id: str, ban: bool = False):
        self.admitted.discard(device_id)
        if ban:
            self._ban(device_id)
        self._changed()

    def unban_all(self):
        self.banned_devices.clear()
        self.banned_ips.clear()
        self._changed()

    def _ban(self, device_id: str):
        self.admitted.discard(device_id)
        self.banned_devices.add(device_id)
        ip = self._ips.get(device_id)
        # Local addresses are shared (and loopback is the tunnel itself).
        if ip and not ip.startswith(("127.", "::1")):
            self.banned_ips.add(ip)
        LOG.info("Device %s banned", device_id)

    # Host view

    def to_payload(self) -> dict:
        return {
            "lanMode": self.modes["lan"],
            "onlineMode": self.modes["online"],
            "passwordSet": bool(self.password),
            "pending": [r.to_payload() for r in sorted(self.pending.values(), key=lambda r: r.since)],
            "bannedCount": len(self.banned_devices),
        }

    def _changed(self):
        if self._on_change is not None:
            try:
                self._on_change(self.to_payload())
            except Exception:
                LOG.exception("Access listener failed")
