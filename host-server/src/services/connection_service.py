from __future__ import annotations

from dataclasses import dataclass
import ipaddress
import json
import logging
import os
from pathlib import Path
import socket
import subprocess
import time
from typing import Any

import psutil

LOG = logging.getLogger("connection_service")

ConnectionKind = str

_BLOCKED_HINTS = (
    "openvpn",
    "wintun",
    "wireguard",
    "tailscale",
    "zerotier",
    "hamachi",
    "vpn",
    "tunnel",
    "teredo",
    "isatap",
    "6to4",
    "bluetooth",
    "loopback",
    "vmware",
    "virtualbox",
    "hyper-v",
    "vethernet",
    "docker",
    "npcap",
    "tap-",
    "tap ",
    "tun-",
    "tun ",
)

_HOTSPOT_HINTS = (
    "hotspot",
    "wi-fi direct",
    "wifi direct",
    "hosted network",
    "mobile hotspot",
)

_WIFI_HINTS = (
    "wi-fi",
    "wifi",
    "wlan",
    "wireless",
    "802.11",
)

_ETHERNET_HINTS = (
    "ethernet",
    "gigabit",
    "local area connection",
    "lan",
    "realtek pci",
    "intel(r) ethernet",
)


@dataclass
class PersistedConnectionState:
    preferred_connection_id: str | None = None
    previous_interface_id: str | None = None
    last_successful_connection_id: str | None = None
    last_successful_kind: str | None = None

    @classmethod
    def from_json(cls, payload: dict[str, Any]) -> "PersistedConnectionState":
        return cls(
            preferred_connection_id=payload.get("preferred_connection_id"),
            previous_interface_id=payload.get("previous_interface_id"),
            last_successful_connection_id=payload.get("last_successful_connection_id"),
            last_successful_kind=payload.get("last_successful_kind"),
        )

    def to_json(self) -> dict[str, Any]:
        return {
            "preferred_connection_id": self.preferred_connection_id,
            "previous_interface_id": self.previous_interface_id,
            "last_successful_connection_id": self.last_successful_connection_id,
            "last_successful_kind": self.last_successful_kind,
        }


@dataclass
class ConnectionOption:
    id: str
    interface_id: str
    interface_name: str
    display_name_key: str
    ip: str
    kind: ConnectionKind
    has_gateway: bool
    score: int
    recommended: bool = False
    selected: bool = False
    preferred: bool = False
    last_successful: bool = False

    def to_payload(self, port: int, ws_endpoint: str) -> dict[str, Any]:
        url = f"http://{self.ip}:{port}"
        return {
            "id": self.id,
            "displayNameKey": self.display_name_key,
            "ip": self.ip,
            "kind": self.kind,
            "url": url,
            "wsUrl": f"ws://{self.ip}:{port}{ws_endpoint}",
            "recommended": self.recommended,
            "selected": self.selected,
            "preferred": self.preferred,
            "lastSuccessful": self.last_successful,
        }


@dataclass
class ConnectionSnapshot:
    selected: ConnectionOption
    connections: list[ConnectionOption]


class ConnectionStateStore:
    def __init__(self, state_path: Path | None = None):
        self.state_path = state_path or self._default_state_path()

    def load(self) -> PersistedConnectionState:
        try:
            if not self.state_path.exists():
                return PersistedConnectionState()
            payload = json.loads(self.state_path.read_text(encoding="utf-8"))
            if not isinstance(payload, dict):
                return PersistedConnectionState()
            return PersistedConnectionState.from_json(payload)
        except Exception as exc:
            LOG.warning("Failed to load connection state: %s", exc)
            return PersistedConnectionState()

    def save(self, state: PersistedConnectionState) -> None:
        try:
            self.state_path.parent.mkdir(parents=True, exist_ok=True)
            temp_path = self.state_path.with_suffix(".tmp")
            temp_path.write_text(
                json.dumps(state.to_json(), indent=2),
                encoding="utf-8",
            )
            temp_path.replace(self.state_path)
        except Exception as exc:
            LOG.warning("Failed to save connection state: %s", exc)

    def _default_state_path(self) -> Path:
        local_appdata = os.getenv("LOCALAPPDATA")
        if local_appdata:
            return Path(local_appdata) / "ma-net" / "connection_state.json"
        return Path.home() / ".ma-net" / "connection_state.json"


class ConnectionService:
    def __init__(self, port: int, ws_endpoint: str):
        self.port = port
        self.ws_endpoint = ws_endpoint
        self._state_store = ConnectionStateStore()
        self._snapshot_cache: ConnectionSnapshot | None = None
        self._snapshot_cache_at = 0.0
        self._ip_index: dict[str, ConnectionOption] = {}

    def get_connections_payload(self) -> dict[str, Any]:
        snapshot = self.get_snapshot()
        return {
            "success": True,
            "selectedConnection": snapshot.selected.to_payload(
                self.port,
                self.ws_endpoint,
            ),
            "connections": [
                option.to_payload(self.port, self.ws_endpoint)
                for option in snapshot.connections
            ],
        }

    def get_connection_info_payload(self) -> dict[str, Any]:
        selected = self.get_snapshot().selected
        return selected.to_payload(self.port, self.ws_endpoint)

    def get_qr_url_for_id(self, connection_id: str | None) -> str:
        option = self.get_connection_by_id(connection_id)
        return f"http://{option.ip}:{self.port}"

    def set_preferred_connection(self, connection_id: str) -> ConnectionOption:
        option = self.get_connection_by_id(connection_id)
        state = self._state_store.load()
        state.preferred_connection_id = option.id
        state.previous_interface_id = option.interface_id
        self._state_store.save(state)
        self._invalidate_cache()
        return option

    def mark_success_for_ip(self, ip: str | None) -> None:
        if not ip or ip.startswith("127."):
            return

        match = self._ip_index.get(ip)
        if match is None:
            return

        state = self._state_store.load()
        if (
            state.last_successful_connection_id == match.id
            and state.last_successful_kind == match.kind
            and state.previous_interface_id == match.interface_id
        ):
            return
        state.last_successful_connection_id = match.id
        state.last_successful_kind = match.kind
        state.previous_interface_id = match.interface_id
        self._state_store.save(state)
        self._invalidate_cache()

    def get_snapshot(self) -> ConnectionSnapshot:
        now = time.monotonic()
        if self._snapshot_cache is not None and now - self._snapshot_cache_at < 2:
            return self._snapshot_cache

        state = self._state_store.load()
        options = self._discover_options(state)

        if not options:
            fallback = ConnectionOption(
                id="loopback",
                interface_id="loopback",
                interface_name="Loopback",
                display_name_key="connection_label_this_device",
                ip="127.0.0.1",
                kind="unknown",
                has_gateway=False,
                score=-1,
            )
            fallback.selected = True
            fallback.recommended = True
            snapshot = ConnectionSnapshot(selected=fallback, connections=[fallback])
            self._snapshot_cache = snapshot
            self._snapshot_cache_at = now
            self._ip_index = {fallback.ip: fallback}
            return snapshot

        recommended_id = max(options, key=lambda item: item.score).id
        selected_id = self._resolve_selected_id(options, state, recommended_id)

        for option in options:
            option.recommended = option.id == recommended_id
            option.selected = option.id == selected_id
            option.preferred = option.id == state.preferred_connection_id
            option.last_successful = option.id == state.last_successful_connection_id

        selected = next(item for item in options if item.id == selected_id)
        snapshot = ConnectionSnapshot(selected=selected, connections=options)
        self._snapshot_cache = snapshot
        self._snapshot_cache_at = now
        self._ip_index = {item.ip: item for item in options}
        return snapshot

    def refresh_snapshot(self) -> ConnectionSnapshot:
        self._invalidate_cache()
        return self.get_snapshot()

    def get_connection_by_id(self, connection_id: str | None) -> ConnectionOption:
        snapshot = self.get_snapshot()
        if not connection_id:
            return snapshot.selected

        for option in snapshot.connections:
            if option.id == connection_id:
                return option

        return snapshot.selected

    def _resolve_selected_id(
        self,
        options: list[ConnectionOption],
        state: PersistedConnectionState,
        recommended_id: str,
    ) -> str:
        option_ids = {item.id for item in options}
        interface_ids = {item.interface_id for item in options}

        if state.preferred_connection_id in option_ids:
            return state.preferred_connection_id
        if state.last_successful_connection_id in option_ids:
            return state.last_successful_connection_id
        if state.previous_interface_id in interface_ids:
            for option in options:
                if option.interface_id == state.previous_interface_id:
                    return option.id
        return recommended_id

    def _discover_options(
        self,
        state: PersistedConnectionState,
    ) -> list[ConnectionOption]:
        addrs_by_interface = psutil.net_if_addrs()
        stats_by_interface = psutil.net_if_stats()
        windows_meta = self._load_windows_network_metadata()
        wifi_ssids = self._get_wifi_ssids(set(addrs_by_interface.keys()))

        options: list[ConnectionOption] = []
        name_counts: dict[str, int] = {}

        for iface_name, iface_addrs in addrs_by_interface.items():
            iface_stats = stats_by_interface.get(iface_name)
            if iface_stats is None or not iface_stats.isup:
                continue

            meta = windows_meta.get(iface_name, {})
            interface_id = self._normalize_interface_id(iface_name, meta)
            kind = self._classify_kind(iface_name, meta)
            if self._should_ignore_interface(iface_name, meta, kind):
                continue

            has_gateway = bool(meta.get("gateway"))

            for snic in iface_addrs:
                if snic.family != socket.AF_INET:
                    continue
                if not self._is_valid_local_ipv4(snic.address):
                    continue

                score = self._score_candidate(
                    kind=kind,
                    has_gateway=has_gateway,
                    interface_id=interface_id,
                    state=state,
                )

                profile_name = meta.get("profile_name", "")
                if kind == "wifi" and iface_name in wifi_ssids:
                    profile_name = wifi_ssids[iface_name]
                display_name_key = self._build_display_name_key(kind, name_counts, profile_name)
                connection_id = self._build_connection_id(interface_id, snic.address)

                options.append(
                    ConnectionOption(
                        id=connection_id,
                        interface_id=interface_id,
                        interface_name=iface_name,
                        display_name_key=display_name_key,
                        ip=snic.address,
                        kind=kind,
                        has_gateway=has_gateway,
                        score=score,
                    )
                )

        options.sort(key=lambda item: (-item.score, item.display_name_key, item.ip))
        return options

    def _score_candidate(
        self,
        *,
        kind: ConnectionKind,
        has_gateway: bool,
        interface_id: str,
        state: PersistedConnectionState,
    ) -> int:
        score = 20
        if has_gateway:
            score += 45

        if kind == "wifi":
            score += 30
        elif kind == "ethernet":
            score += 28
        elif kind == "hotspot":
            score += 27
        else:
            score += 8

        if state.previous_interface_id == interface_id:
            score += 25
        if state.last_successful_kind == kind:
            score += 8

        return score

    def _load_windows_network_metadata(self) -> dict[str, dict[str, Any]]:
        if os.name != "nt":
            return {}

        command = [
            "powershell",
            "-NoProfile",
            "-Command",
            (
                "Get-NetIPConfiguration | ForEach-Object { "
                "[pscustomobject]@{ "
                "InterfaceAlias = $_.InterfaceAlias; "
                "InterfaceDescription = $_.InterfaceDescription; "
                "IPv4Gateway = @($_.IPv4DefaultGateway | ForEach-Object { $_.NextHop }); "
                "NetProfileName = $_.NetProfile.Name "
                "} "
                "} | ConvertTo-Json -Compress"
            ),
        ]

        try:
            result = subprocess.run(
                command,
                capture_output=True,
                check=False,
                text=True,
                timeout=3,
                creationflags=0x08000000,
            )
        except Exception as exc:
            LOG.debug("Failed to inspect Windows network metadata: %s", exc)
            return {}

        if result.returncode != 0 or not result.stdout.strip():
            return {}

        try:
            payload = json.loads(result.stdout)
        except json.JSONDecodeError:
            return {}

        if isinstance(payload, dict):
            items = [payload]
        elif isinstance(payload, list):
            items = payload
        else:
            return {}

        metadata: dict[str, dict[str, Any]] = {}
        for item in items:
            if not isinstance(item, dict):
                continue
            alias = item.get("InterfaceAlias")
            if not alias:
                continue

            gateways = item.get("IPv4Gateway")
            if isinstance(gateways, list):
                gateway = next((value for value in gateways if value), None)
            else:
                gateway = gateways

            metadata[alias] = {
                "description": item.get("InterfaceDescription") or "",
                "gateway": gateway,
                "profile_name": item.get("NetProfileName") or "",
            }

        return metadata

    def _get_wifi_ssids(self, known_ifaces: set[str]) -> dict[str, str]:
        if os.name != "nt":
            return {}
        try:
            result = subprocess.run(
                ["netsh", "wlan", "show", "interfaces"],
                capture_output=True,
                check=False,
                text=True,
                creationflags=0x08000000,
            )
            ssids = {}
            current_iface = None
            for line in result.stdout.splitlines():
                line = line.strip()
                if ":" in line:
                    key, val = line.split(":", 1)
                    key = key.strip().lower()
                    val = val.strip()
                    
                    if val in known_ifaces:
                        current_iface = val
                    elif key == "ssid" and current_iface:
                        if val:
                            ssids[current_iface] = val
            return ssids
        except Exception as exc:
            LOG.debug("Failed to get wifi ssids: %s", exc)
            return {}

    def _normalize_interface_id(self, iface_name: str, meta: dict[str, Any]) -> str:
        source = f"{iface_name}|{meta.get('description', '')}".strip().lower()
        compact = "".join(char if char.isalnum() else "-" for char in source)
        while "--" in compact:
            compact = compact.replace("--", "-")
        return compact.strip("-") or "unknown-interface"

    def _build_connection_id(self, interface_id: str, ip: str) -> str:
        safe_ip = ip.replace(".", "-")
        return f"{interface_id}-{safe_ip}"

    def _is_valid_local_ipv4(self, address: str) -> bool:
        try:
            ip = ipaddress.ip_address(address)
        except ValueError:
            return False

        if ip.version != 4 or ip.is_loopback or ip.is_link_local:
            return False

        return bool(ip.is_private)

    def _should_ignore_interface(
        self,
        iface_name: str,
        meta: dict[str, Any],
        kind: ConnectionKind,
    ) -> bool:
        haystack = " ".join(
            [
                iface_name.lower(),
                str(meta.get("description", "")).lower(),
                str(meta.get("profile_name", "")).lower(),
            ]
        )

        if kind == "hotspot":
            return False

        return any(hint in haystack for hint in _BLOCKED_HINTS)

    def _classify_kind(self, iface_name: str, meta: dict[str, Any]) -> ConnectionKind:
        haystack = " ".join(
            [
                iface_name.lower(),
                str(meta.get("description", "")).lower(),
                str(meta.get("profile_name", "")).lower(),
            ]
        )

        if any(hint in haystack for hint in _HOTSPOT_HINTS):
            return "hotspot"
        if any(hint in haystack for hint in _WIFI_HINTS):
            return "wifi"
        if any(hint in haystack for hint in _ETHERNET_HINTS):
            return "ethernet"
        return "unknown"

    def _build_display_name_key(
        self,
        kind: ConnectionKind,
        counts: dict[str, int],
        profile_name: str = "",
    ) -> str:
        base_name = {
            "wifi": "connection_label_wifi",
            "ethernet": "connection_label_ethernet",
            "hotspot": "connection_label_hotspot",
            "unknown": "connection_label_backup",
        }.get(kind, "connection_label_backup")

        if profile_name:
            return f"{base_name}__{profile_name}"

        counts[base_name] = counts.get(base_name, 0) + 1
        if counts[base_name] == 1:
            return base_name
        return f"{base_name}__{counts[base_name]}"

    def _invalidate_cache(self) -> None:
        self._snapshot_cache = None
        self._snapshot_cache_at = 0.0
        self._ip_index = {}
