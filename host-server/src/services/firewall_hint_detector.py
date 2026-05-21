from __future__ import annotations

from typing import Any


class FirewallHintDetector:
    def build_hints(
        self,
        *,
        uptime_seconds: float,
        connected_client_count: int,
        selected_is_loopback: bool,
        active_connection_count: int,
        has_hotspot: bool,
    ) -> list[dict[str, Any]]:
        checks: list[dict[str, Any]] = []

        if (
            uptime_seconds >= 45
            and connected_client_count == 0
            and active_connection_count > 0
            and not selected_is_loopback
        ):
            checks.append(
                {
                    "id": "firewall_hint",
                    "level": "warn",
                    "icon": "shield",
                    "titleKey": "diag_title_firewall_hint",
                    "bodyKey": "diag_body_firewall_hint",
                    "actionIds": ["open_firewall_settings"],
                }
            )

        if (
            uptime_seconds >= 25
            and connected_client_count == 0
            and has_hotspot
        ):
            checks.append(
                {
                    "id": "hotspot_waiting",
                    "level": "warn",
                    "icon": "wifi_tethering",
                    "titleKey": "diag_title_hotspot_waiting",
                    "bodyKey": "diag_body_hotspot_waiting",
                    "actionIds": [
                        "open_firewall_settings",
                        "refresh_networks",
                    ],
                }
            )

        return checks
