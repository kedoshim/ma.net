from __future__ import annotations

from dataclasses import dataclass
from typing import Any

from src.services.connection_service import ConnectionSnapshot


@dataclass
class ConnectivityFacts:
    active_connection_count: int
    available_connection_count: int
    has_hotspot: bool
    has_multiple_connections: bool
    selected_is_loopback: bool
    selected_has_gateway: bool
    selected_kind: str


class ConnectivityChecker:
    def build_facts(self, snapshot: ConnectionSnapshot) -> ConnectivityFacts:
        available_connections = snapshot.connections
        active_connections = [
            connection for connection in available_connections
            if connection.ip != "127.0.0.1"
        ]
        selected = snapshot.selected

        return ConnectivityFacts(
            active_connection_count=len(active_connections),
            available_connection_count=len(available_connections),
            has_hotspot=any(
                connection.kind == "hotspot"
                for connection in available_connections
            ),
            has_multiple_connections=len(active_connections) > 1,
            selected_is_loopback=selected.ip == "127.0.0.1",
            selected_has_gateway=selected.has_gateway,
            selected_kind=selected.kind,
        )

    def build_quick_status_checks(
        self,
        *,
        snapshot: ConnectionSnapshot,
    ) -> list[dict[str, Any]]:
        facts = self.build_facts(snapshot)

        checks: list[dict[str, Any]] = [
            {
                "id": "server_started",
                "level": "ok",
                "icon": "play_circle",
                "titleKey": "diag_title_server_started",
                "bodyKey": "diag_body_server_started",
            },
            {
                "id": "qr_ready",
                "level": "ok",
                "icon": "qr_code_2",
                "titleKey": "diag_title_qr_ready",
                "bodyKey": "diag_body_qr_ready",
            },
        ]

        if facts.active_connection_count == 0:
            checks.append(
                {
                    "id": "no_active_ipv4",
                    "level": "warn",
                    "icon": "wifi_off",
                    "titleKey": "diag_title_no_network",
                    "bodyKey": "diag_body_no_network",
                    "actionIds": ["refresh_networks"],
                }
            )

        if facts.selected_is_loopback:
            checks.append(
                {
                    "id": "localhost_only",
                    "level": "warn",
                    "icon": "route",
                    "titleKey": "diag_title_local_only",
                    "bodyKey": "diag_body_local_only",
                    "actionIds": ["refresh_networks"],
                }
            )

        if facts.has_multiple_connections:
            checks.append(
                {
                    "id": "multiple_connections",
                    "level": "warn",
                    "icon": "hub",
                    "titleKey": "diag_title_multiple_networks",
                    "bodyKey": "diag_body_multiple_networks",
                    "actionIds": ["refresh_networks"],
                }
            )

        if facts.has_hotspot:
            checks.append(
                {
                    "id": "hotspot_public_permission",
                    "level": "warn",
                    "icon": "portable_wifi_off",
                    "titleKey": "diag_title_hotspot_permission",
                    "bodyKey": "diag_body_hotspot_permission",
                    "actionIds": ["open_firewall_settings"],
                }
            )

        return checks
