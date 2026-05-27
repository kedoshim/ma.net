from __future__ import annotations

from dataclasses import dataclass
import os
import subprocess
import time
from typing import Any

from src.services.connection_service import ConnectionService
from src.services.connectivity_checker import ConnectivityChecker
from src.services.firewall_hint_detector import FirewallHintDetector


@dataclass
class DiagnosticActionResult:
    success: bool
    code: str

    def to_payload(self) -> dict[str, Any]:
        return {
            "success": self.success,
            "code": self.code,
        }


class NetworkDiagnosticsService:
    def __init__(self, manager, connection_service: ConnectionService):
        self.manager = manager
        self.connection_service = connection_service
        self.connectivity_checker = ConnectivityChecker()
        self.firewall_hint_detector = FirewallHintDetector()
        self.started_at = time.monotonic()

    def build_payload(self) -> dict[str, Any]:
        snapshot = self.connection_service.get_snapshot()
        facts = self.connectivity_checker.build_facts(snapshot)
        uptime_seconds = time.monotonic() - self.started_at
        connected_client_count = len(self.manager.connected_devices)

        checks = self.connectivity_checker.build_quick_status_checks(
            snapshot=snapshot,
        )
        checks.extend(
            self.firewall_hint_detector.build_hints(
                uptime_seconds=uptime_seconds,
                connected_client_count=connected_client_count,
                selected_is_loopback=facts.selected_is_loopback,
                active_connection_count=facts.active_connection_count,
                has_hotspot=facts.has_hotspot,
            )
        )

        attention_count = sum(
            1 for check in checks
            if check.get("level") == "warn"
        )

        return {
            "success": True,
            "health": "attention" if attention_count > 0 else "healthy",
            "attentionNeeded": attention_count > 0,
            "attentionCount": attention_count,
            "connectedClientCount": connected_client_count,
            "checks": checks,
            "quickActions": self._build_quick_actions(
                can_open_windows_settings=os.name == "nt",
            ),
        }

    def run_action(self, action_id: str) -> DiagnosticActionResult:
        if action_id == "refresh_networks":
            self.connection_service.refresh_snapshot()
            return DiagnosticActionResult(True, "diagnostics_refreshed")

        if os.name != "nt":
            return DiagnosticActionResult(False, "action_not_supported")

        command_map = {
            "open_firewall_settings": ["control.exe", "/name", "WindowsFirewall"],
            "open_firewall_advanced": ["wf.msc"],
        }

        command = command_map.get(action_id)
        if command is None:
            return DiagnosticActionResult(False, "unknown_action")

        try:
            subprocess.Popen(command)
            return DiagnosticActionResult(True, "action_launched")
        except Exception:
            return DiagnosticActionResult(False, "action_failed")

    def _build_quick_actions(
        self,
        *,
        can_open_windows_settings: bool,
    ) -> list[dict[str, Any]]:
        actions: list[dict[str, Any]] = [
            {
                "id": "refresh_networks",
                "labelKey": "diag_action_refresh",
                "icon": "refresh",
                "kind": "refresh",
            },
            {
                "id": "copy_server_url",
                "labelKey": "diag_action_copy_link",
                "icon": "content_copy",
                "kind": "client",
            },
        ]

        if can_open_windows_settings:
            actions.extend(
                [
                    {
                        "id": "open_firewall_settings",
                        "labelKey": "diag_action_firewall",
                        "icon": "shield",
                        "kind": "server",
                    },
                    {
                        "id": "open_firewall_advanced",
                        "labelKey": "diag_action_firewall_advanced",
                        "icon": "admin_panel_settings",
                        "kind": "server",
                    },
                ]
            )

        return actions
