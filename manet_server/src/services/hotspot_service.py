"""The PC's Windows Mobile Hotspot: is it on, and which network is it.

Windows only tells the name and password through WinRT's tethering
manager, which we reach from PowerShell. When that fails (no internet
profile, older Windows, not Windows) the adapters still give it away: the
hotspot is a "Wi-Fi Direct" adapter and Windows hands it 192.168.137.x.
Then we know it is on, but not its name.
"""

import json
import logging
import os
import subprocess
import time
from dataclasses import dataclass

LOG = logging.getLogger("hotspot")

HOTSPOT_SUBNET = "192.168.137."
CACHE_SECONDS = 30.0

_POWERSHELL_SCRIPT = (
    "$ErrorActionPreference = 'Stop'; "
    "[void][Windows.Networking.Connectivity.NetworkInformation,Windows.Networking.Connectivity,ContentType=WindowsRuntime]; "
    "[void][Windows.Networking.NetworkOperators.NetworkOperatorTetheringManager,Windows.Networking.NetworkOperators,ContentType=WindowsRuntime]; "
    "$profile = [Windows.Networking.Connectivity.NetworkInformation]::GetInternetConnectionProfile(); "
    "if ($profile -eq $null) { '{\"state\":\"NoProfile\"}'; exit }; "
    "$manager = [Windows.Networking.NetworkOperators.NetworkOperatorTetheringManager]::CreateFromConnectionProfile($profile); "
    "$config = $manager.GetCurrentAccessPointConfiguration(); "
    "[pscustomobject]@{ state = $manager.TetheringOperationalState.ToString(); "
    "ssid = $config.Ssid; passphrase = $config.Passphrase } | ConvertTo-Json -Compress"
)


@dataclass(frozen=True)
class HotspotInfo:
    active: bool = False
    ssid: str | None = None
    passphrase: str | None = None

    def to_payload(self) -> dict:
        """What the desktop sees; the password itself stays in the QR."""
        return {"active": self.active, "ssid": self.ssid, "hasPassword": bool(self.passphrase)}


def parse_tethering_output(stdout: str) -> HotspotInfo | None:
    """None when the output says nothing usable (fall back to adapters)."""
    try:
        data = json.loads(stdout.strip() or "null")
    except ValueError:
        return None
    if not isinstance(data, dict):
        return None
    state = str(data.get("state") or "")
    if state not in ("On", "Off", "InTransition"):
        return None
    if state != "On":
        return HotspotInfo()
    ssid = data.get("ssid") or None
    passphrase = data.get("passphrase") or None
    return HotspotInfo(active=True, ssid=ssid, passphrase=passphrase)


def hotspot_from_options(options) -> HotspotInfo:
    """The adapters' view: on when one looks like the hotspot, name unknown."""
    for option in options:
        if getattr(option, "kind", None) == "hotspot" or str(getattr(option, "ip", "")).startswith(HOTSPOT_SUBNET):
            return HotspotInfo(active=True)
    return HotspotInfo()


def _escape_wifi(value: str) -> str:
    for char in ("\\", ";", ",", ":", '"'):
        value = value.replace(char, "\\" + char)
    return value


def wifi_qr_payload(ssid: str, passphrase: str | None) -> str:
    """The text phone cameras read as "join this Wi-Fi"."""
    if passphrase:
        return f"WIFI:T:WPA;S:{_escape_wifi(ssid)};P:{_escape_wifi(passphrase)};;"
    return f"WIFI:T:nopass;S:{_escape_wifi(ssid)};;"


class HotspotService:
    def __init__(self, connection_service):
        self._connection_service = connection_service
        self._info = HotspotInfo()
        self._checked_at = 0.0

    def get(self) -> HotspotInfo:
        """Cached; the network monitor refreshes it when adapters change."""
        if time.monotonic() - self._checked_at > CACHE_SECONDS:
            return self.refresh()
        return self._info

    def refresh(self) -> HotspotInfo:
        info = self._query_windows()
        if info is None:
            try:
                options = self._connection_service.get_snapshot().connections
            except Exception as exc:
                LOG.debug("Hotspot fallback could not read adapters: %s", exc)
                options = []
            info = hotspot_from_options(options)
        if info != self._info:
            LOG.info("Hotspot: %s", "on (%s)" % (info.ssid or "unknown name") if info.active else "off")
        self._info = info
        self._checked_at = time.monotonic()
        return info

    def _query_windows(self) -> HotspotInfo | None:
        if os.name != "nt":
            return None
        try:
            result = subprocess.run(
                ["powershell", "-NoProfile", "-Command", _POWERSHELL_SCRIPT],
                capture_output=True,
                check=False,
                text=True,
                timeout=5,
                creationflags=0x08000000,
            )
        except Exception as exc:
            LOG.debug("Hotspot query failed: %s", exc)
            return None
        if result.returncode != 0:
            LOG.debug("Hotspot query exited %s: %s", result.returncode, result.stderr.strip()[:200])
            return None
        return parse_tethering_output(result.stdout)
