
import asyncio
from io import BytesIO
from pathlib import Path
import uuid

from aiohttp import web

from src.services.qr_service import generate_qr_code_image
from src.lifecycle.process_exit import exit_process
from src.core.game_library import GameValidationError
from src.services.window_placement import list_displays
from src.services.controller_inventory import build_inventory, close_other_servers, snapshot_own_pads
from src.services.connection_service import ConnectionService
from src.services.hotspot_service import HotspotInfo, wifi_qr_payload
from src.services.network_diagnostics_service import NetworkDiagnosticsService
from src.core.slot_handler import notify_device_slot, notify_device_unassigned

import logging
LOG = logging.getLogger("http_routes")


class BadRequest(Exception):
    pass


async def _read_json_object(request) -> dict:
    try:
        data = await request.json()
    except Exception:
        raise BadRequest("invalid_json")
    if not isinstance(data, dict):
        raise BadRequest("invalid_body")
    return data


def _bad_request(code: str):
    return web.json_response({"success": False, "code": code}, status=400)


def _render_qr_png(url: str) -> bytes:
    img = generate_qr_code_image(url)
    buffer = BytesIO()
    img.save(buffer, format="PNG")
    return buffer.getvalue()


class HTTPRoutes:
    def __init__(
        self,
        manager,
        admin_panel,
        port,
        ws_endpoint,
        connection_service: ConnectionService,
        diagnostics_service: NetworkDiagnosticsService,
        tunnel_service=None,
        access_gate=None,
    ):
        self.manager = manager
        self.admin_panel = admin_panel
        self.port = port
        self.ws_endpoint = ws_endpoint
        self.connection_service = connection_service
        self.diagnostics_service = diagnostics_service
        self.tunnel_service = tunnel_service
        self.access_gate = access_gate
        self.session = manager.session
        # QR rendering is CPU-bound; the URL rarely changes.
        self._qr_cache: dict[str, bytes] = {}

    def _slot_index(self, data: dict, key: str) -> int:
        value = data.get(key)
        if isinstance(value, bool) or not isinstance(value, int):
            raise BadRequest(f"invalid_{key}")
        if not 0 <= value < len(self.manager.slots):
            raise BadRequest("slot_out_of_range")
        return value


    async def server_status_handler(self, request):
        info = await asyncio.to_thread(self.connection_service.get_connection_info_payload)
        return web.json_response({
            'running': True,
            'ip': info['ip'],
            'port': self.port
        })


    async def server_start_handler(self, request):
        # Server is always running
        return web.json_response({'success': True})


    async def server_stop_handler(self, request):
        # For now, just return success
        return web.json_response({'success': True})


    async def server_shutdown_handler(self, request):
        """Release the virtual gamepads and exit right after replying, so the
        desktop doesn't have to kill the process (and no ghost controllers
        are left behind in Windows)."""
        exit_process(self.manager, asyncio.get_running_loop(), "requested by host")
        return web.json_response({'success': True})


    async def online_status_handler(self, request):
        return web.json_response({"success": True, **self.tunnel_service.snapshot()})


    async def online_start_handler(self, request):
        self.tunnel_service.start()
        return web.json_response({"success": True, **self.tunnel_service.snapshot()})


    async def online_stop_handler(self, request):
        await self.tunnel_service.stop()
        return web.json_response({"success": True, **self.tunnel_service.snapshot()})


    async def access_handler(self, request):
        return web.json_response({"success": True, **self.access_gate.to_payload()})


    async def access_settings_handler(self, request):
        try:
            data = await _read_json_object(request)
        except BadRequest as e:
            return _bad_request(str(e))
        self.access_gate.configure(
            lan=data.get("lanMode"),
            online=data.get("onlineMode"),
            password=data.get("password") if "password" in data else None,
            online_password=data.get("onlinePassword") if "onlinePassword" in data else None,
            lan_enabled=data.get("lanEnabled"),
        )
        return web.json_response({"success": True, **self.access_gate.to_payload()})


    async def access_answer_handler(self, request):
        try:
            data = await _read_json_object(request)
        except BadRequest as e:
            return _bad_request(str(e))
        device_id = data.get("deviceId")
        if not isinstance(device_id, str) or not device_id:
            return _bad_request("invalid_deviceId")
        found = self.access_gate.answer(device_id, data.get("accept") is True, data.get("ban") is True)
        return web.json_response({"success": found})


    async def access_kick_handler(self, request):
        """Removes a connected phone; with `ban` it can't come back this
        session."""
        try:
            data = await _read_json_object(request)
        except BadRequest as e:
            return _bad_request(str(e))
        device_id = data.get("deviceId")
        if not isinstance(device_id, str) or not device_id:
            return _bad_request("invalid_deviceId")
        ban = data.get("ban") is True
        if device_id in self.access_gate.pending:
            self.access_gate.answer(device_id, False, ban)
        else:
            self.access_gate.kick(device_id, ban)
        ws = self.manager.device_ws_map.get(device_id)
        if ws is not None and not ws.closed:
            try:
                await ws.send_json({"type": "access_denied", "reason": "banned" if ban else "kicked"})
            except Exception:
                pass
            await ws.close()
        return web.json_response({"success": True})


    async def access_unban_handler(self, request):
        self.access_gate.unban_all()
        return web.json_response({"success": True, **self.access_gate.to_payload()})


    async def connection_info_handler(self, request):
        payload = await asyncio.to_thread(self.connection_service.get_connection_info_payload)
        return web.json_response({
            "success": True,
            "url": payload["url"],
            "wsUrl": payload["wsUrl"],
            "ip": payload["ip"],
            "kind": payload["kind"],
        })


    async def connections_handler(self, request):
        payload = await asyncio.to_thread(self.connection_service.get_connections_payload)
        return web.json_response(payload)


    async def diagnostics_handler(self, request):
        payload = await asyncio.to_thread(self.diagnostics_service.build_payload)
        return web.json_response(payload)


    async def diagnostics_action_handler(self, request):
        data = await request.json()
        action_id = data.get("actionId")
        if not action_id:
            return web.json_response(
                {"success": False, "code": "missing_action_id"},
                status=400,
            )

        result = await asyncio.to_thread(self.diagnostics_service.run_action, action_id)
        status = 200 if result.success else 400
        return web.json_response(result.to_payload(), status=status)


    async def select_connection_handler(self, request):
        data = await request.json()
        connection_id = data.get("connectionId")
        if not connection_id:
            return web.json_response(
                {"success": False, "code": "missing_connection_id"},
                status=400,
            )

        try:
            option = await asyncio.to_thread(self.connection_service.set_preferred_connection, connection_id)
        except Exception as exc:
            LOG.error("Failed to select connection: %s", exc)
            return web.json_response(
                {"success": False, "code": "select_connection_failed"},
                status=400,
            )

        return web.json_response({
            "success": True,
            "selectedConnection": option.to_payload(self.port, self.ws_endpoint),
        })


    async def qr_code_handler(self, request):
        connection_id = request.query.get("id")
        url = await asyncio.to_thread(self.connection_service.get_qr_url_for_id, connection_id)

        try:
            png = self._qr_cache.get(url)
            if png is None:
                png = await asyncio.to_thread(_render_qr_png, url)
                self._qr_cache[url] = png

            return web.Response(
                body=png,
                content_type="image/png"
            )
        except Exception as e:
            LOG.error("Failed to generate QR code: %s", e)
            return web.json_response(
                {"success": False, "code": "qr_generation_failed"},
                status=500
            )

    def _hotspot(self):
        return getattr(self.connection_service, "hotspot_service", None)

    async def hotspot_handler(self, request):
        service = self._hotspot()
        info = await asyncio.to_thread(service.get) if service else HotspotInfo()
        return web.json_response({"success": True, **info.to_payload()})

    async def hotspot_qr_handler(self, request):
        """QR that joins a phone to the PC's hotspot (it holds the password,
        so it is admin-only like every /api/ route)."""
        service = self._hotspot()
        info = await asyncio.to_thread(service.get) if service else HotspotInfo()
        if not info.active or not info.ssid:
            return web.json_response({"success": False, "code": "hotspot_unavailable"}, status=404)
        payload = wifi_qr_payload(info.ssid, info.passphrase)
        try:
            png = self._qr_cache.get(payload)
            if png is None:
                png = await asyncio.to_thread(_render_qr_png, payload)
                self._qr_cache[payload] = png
            return web.Response(body=png, content_type="image/png")
        except Exception as e:
            LOG.error("Failed to generate hotspot QR code: %s", e)
            return web.json_response({"success": False, "code": "qr_generation_failed"}, status=500)

    async def presets_handler(self, request):
        if request.query.get("format") == "catalog" or request.query.get("catalog") == "true":
            return web.json_response(self.manager.preset_store.list_payload())
        
        presets = []
        for preset in self.manager.preset_store.all_presets_by_id.values():
            presets.append({
                "id": preset["id"],
                "name": preset["name"]
            })
        return web.json_response(presets)

    async def current_preset_handler(self, request):
        preset = self.manager.preset_store.get_active_preset()
        return web.json_response(preset)

    async def apply_preset_handler(self, request):
        try:
            data = await request.json()
        except Exception:
            LOG.error("[PRESET API] Failed to apply preset: Invalid request body (not valid JSON)")
            return web.json_response(
                {"success": False, "code": "invalid_body", "message": "Invalid JSON body"},
                status=400
            )

        if not isinstance(data, dict):
            LOG.error("[PRESET API] Failed to apply preset: Invalid request body (must be JSON object)")
            return web.json_response(
                {"success": False, "code": "invalid_body", "message": "Request body must be a JSON object"},
                status=400
            )

        preset_id = data.get("presetId")
        preset_name = data.get("presetName")

        if not preset_id and not preset_name:
            LOG.error("[PRESET API] Failed to apply preset: Missing presetId or presetName")
            return web.json_response(
                {"success": False, "code": "invalid_request", "message": "Either presetId or presetName must be provided"},
                status=400
            )

        all_presets = self.manager.preset_store.all_presets_by_id
        if not all_presets:
            identifier = preset_id or preset_name
            LOG.error("[PRESET API] Failed to apply preset %s: No presets available", identifier)
            return web.json_response(
                {"success": False, "code": "empty_presets", "message": "No presets are loaded in the server"},
                status=400
            )

        if preset_id:
            LOG.info("[PRESET API] Applying preset %s", preset_id)
            if preset_id not in all_presets:
                LOG.error("[PRESET API] Failed to apply preset %s: Preset ID not found", preset_id)
                return web.json_response(
                    {"success": False, "code": "preset_not_found", "message": f"Preset ID '{preset_id}' not found"},
                    status=404
                )
            
            try:
                preset = self.manager.preset_store.set_active_preset(preset_id)
                self.manager.broadcast_active_layout()
                LOG.info("[PRESET API] Preset applied successfully")
                return web.json_response({"success": True})
            except Exception as e:
                LOG.error("[PRESET API] Failed to apply preset %s: %s", preset_id, str(e))
                return web.json_response(
                    {"success": False, "code": "apply_failed", "message": str(e)},
                    status=500
                )
        else:
            LOG.info("[PRESET API] Applying preset %s", preset_name)
            # Find matching presets by name
            # 1. Exact case-sensitive match
            matches = [p for p in all_presets.values() if p.get("name") == preset_name]
            if not matches:
                # 2. Case-insensitive and whitespace trimmed match
                target_norm = preset_name.strip().lower()
                matches = [
                    p for p in all_presets.values()
                    if p.get("name") and p["name"].strip().lower() == target_norm
                ]
            
            if len(matches) == 0:
                LOG.error("[PRESET API] Failed to apply preset %s: Preset name not found", preset_name)
                return web.json_response(
                    {"success": False, "code": "preset_not_found", "message": f"Preset name '{preset_name}' not found"},
                    status=404
                )
            
            if len(matches) > 1:
                LOG.error("[PRESET API] Failed to apply preset %s: Multiple presets match the name", preset_name)
                matching_ids = [p["id"] for p in matches]
                return web.json_response(
                    {
                        "success": False,
                        "code": "duplicate_preset_names",
                        "message": f"Multiple presets found with the name '{preset_name}'. Please use presetId instead.",
                        "matches": matching_ids
                    },
                    status=400
                )
            
            # Exactly one match found
            matched_preset = matches[0]
            matched_id = matched_preset["id"]
            try:
                preset = self.manager.preset_store.set_active_preset(matched_id)
                self.manager.broadcast_active_layout()
                LOG.info("[PRESET API] Preset applied successfully")
                return web.json_response({"success": True})
            except Exception as e:
                LOG.error("[PRESET API] Failed to apply preset %s: %s", preset_name, str(e))
                return web.json_response(
                    {"success": False, "code": "apply_failed", "message": str(e)},
                    status=500
                )

    async def select_preset_handler(self, request):
        data = await request.json()
        preset_id = data.get("presetId")
        if not preset_id:
            return web.json_response(
                {"success": False, "code": "missing_preset_id"},
                status=400,
            )

        try:
            preset = self.manager.preset_store.set_active_preset(preset_id)
        except KeyError:
            return web.json_response(
                {"success": False, "code": "preset_not_found"},
                status=404,
            )

        self.manager.broadcast_active_layout()
        return web.json_response({"success": True, "activePreset": preset})

    async def create_preset_handler(self, request):
        data = await request.json()
        payload = {
            "id": f"user-{uuid.uuid4().hex}",
            "name": data.get("name"),
            "description": data.get("description"),
            "bestFor": data.get("bestFor"),
            "pros": data.get("pros"),
            "cons": data.get("cons"),
            "layout": data.get("layout") or {},
        }
        try:
            preset = self.manager.preset_store.create_custom_preset(payload)
            return web.json_response({"success": True, "preset": preset})
        except ValueError as e:
            return web.json_response({"success": False, "code": str(e)}, status=400)

    async def update_preset_handler(self, request):
        preset_id = request.match_info.get("preset_id")
        data = await request.json()

        try:
            preset = self.manager.preset_store.update_custom_preset(
                preset_id,
                {
                    "name": data.get("name"),
                    "description": data.get("description"),
                    "bestFor": data.get("bestFor"),
                    "pros": data.get("pros"),
                    "cons": data.get("cons"),
                    "layout": data.get("layout") or {},
                },
            )
        except KeyError:
            return web.json_response(
                {"success": False, "code": "preset_not_found"},
                status=404,
            )
        except ValueError as e:
            return web.json_response(
                {"success": False, "code": str(e)},
                status=400,
            )

        # Phones already showing this layout get the new version right away;
        # otherwise they kept the old one until another layout was picked.
        if preset_id == self.manager.preset_store.get_active_preset()["id"]:
            self.manager.broadcast_active_layout()
        else:
            self.admin_panel.broadcast_event({
                "type": "preset_update",
                "catalog": self.manager.preset_store.list_payload(),
            })
        return web.json_response({"success": True, "preset": preset})

    async def delete_preset_handler(self, request):
        preset_id = request.match_info.get("preset_id")

        try:
            active_preset = self.manager.preset_store.delete_custom_preset(preset_id)
        except KeyError:
            return web.json_response(
                {"success": False, "code": "preset_not_found"},
                status=404,
            )

        self.manager.broadcast_active_layout()
        return web.json_response({"success": True, "activePreset": active_preset})


    async def slots_handler(self, request):
        pool = self.manager.get_unassigned_devices()
        slots = self.manager.get_slots_state()
        # Removed debug prints that caused UnicodeEncodeError on Windows
        # when player names contained special characters.
        return web.json_response({
            'pool': pool,
            'slots': slots
        })


    async def assign_handler(self, request):
        try:
            data = await _read_json_object(request)
            device_id = data.get('deviceId')
            if not isinstance(device_id, str) or not device_id:
                raise BadRequest("invalid_deviceId")
            slot_index = self._slot_index(data, 'slotIndex')
        except BadRequest as e:
            return _bad_request(str(e))
        slot = self.manager.assign_to_slot(device_id, slot_index)
        if slot:
            self.admin_panel.broadcast_update()
            return web.json_response({'success': True})
        else:
            return web.json_response({'success': False}, status=400)


    async def move_handler(self, request):
        try:
            data = await _read_json_object(request)
            from_slot = self._slot_index(data, 'fromSlot')
            to_slot = self._slot_index(data, 'toSlot')
        except BadRequest as e:
            return _bad_request(str(e))
        old_device = self.manager.slots[from_slot].assigned_device_id
        self.manager.move_slot(from_slot, to_slot)
        if old_device:
            await notify_device_slot(self.manager, old_device)
        self.admin_panel.broadcast_update()
        return web.json_response({'success': True})


    async def swap_handler(self, request):
        try:
            data = await _read_json_object(request)
            slot_a = self._slot_index(data, 'slotA')
            slot_b = self._slot_index(data, 'slotB')
        except BadRequest as e:
            return _bad_request(str(e))
        device_a = self.manager.slots[slot_a].assigned_device_id
        device_b = self.manager.slots[slot_b].assigned_device_id
        self.manager.swap_slots(slot_a, slot_b)
        if device_a:
            await notify_device_slot(self.manager, device_a)
        if device_b:
            await notify_device_slot(self.manager, device_b)
        self.admin_panel.broadcast_update()
        return web.json_response({'success': True})


    async def unassign_handler(self, request):
        try:
            data = await _read_json_object(request)
            slot_index = self._slot_index(data, 'slotIndex')
        except BadRequest as e:
            return _bad_request(str(e))
        device_id = self.manager.slots[slot_index].assigned_device_id
        self.manager.unassign_slot(slot_index)
        await notify_device_unassigned(self.manager, device_id)
        self.admin_panel.broadcast_update()
        return web.json_response({'success': True})

    async def reset_controllers_handler(self, request):
        try:
            data = await _read_json_object(request)
        except BadRequest as e:
            return _bad_request(str(e))
        mode = data.get('mode')
        slots = data.get('slots')
        fixed = data.get('fixed')
        reservation_timeout = data.get('reservationTimeout')

        if mode is not None and mode not in ('x360', 'ds4', 'mixed'):
            return web.json_response({'success': False, 'code': 'invalid_mode'}, status=400)

        # When switching modes, the system will enforce a uniform controller
        # scheme (no mixed types). The manager will recreate gamepads and
        # perform staged creation to reduce driver stress.

        try:
            await self.manager.update_server_settings(
                mode=mode,
                slots=slots,
                fixed=fixed,
                reservation_timeout=reservation_timeout,
            )
            # Notify admin UI about changes
            self.admin_panel.broadcast_update()
            return web.json_response({'success': True})
        except Exception as e:
            LOG.error('Failed to update server settings: %s', e)
            return web.json_response({'success': False, 'code': 'update_failed'}, status=500)

    async def controllers_inventory_handler(self, request):
        own_pads, callback_states = snapshot_own_pads(self.manager)
        payload = await asyncio.to_thread(
            build_inventory,
            own_pads,
            callback_states,
            getattr(self.manager.config, "controller_type", None),
        )
        return web.json_response(payload)

    async def controllers_recreate_handler(self, request):
        try:
            await self.manager.recreate_gamepads()
        except Exception:
            LOG.exception("Failed to recreate gamepads")
            return web.json_response({'success': False, 'code': 'recreate_failed'}, status=500)
        self.admin_panel.broadcast_update()
        return web.json_response({'success': True})

    async def close_stale_servers_handler(self, request):
        closed = await asyncio.to_thread(close_other_servers)
        LOG.info("Closed %d stale MaNet server process(es)", closed)
        return web.json_response({'success': True, 'closed': closed})

    # ------------------------------------------------------------ session

    async def session_handler(self, request):
        return web.json_response(self.session.to_payload())

    async def session_focus_handler(self, request):
        try:
            data = await _read_json_object(request)
        except BadRequest as e:
            return _bad_request(str(e))
        self.session.set_focus(bool(data.get("focused")))
        return web.json_response({"success": True})

    async def session_phase_handler(self, request):
        try:
            data = await _read_json_object(request)
        except BadRequest as e:
            return _bad_request(str(e))
        phase = data.get("phase")
        if phase == "library":
            self.session.enter_library()
        elif phase == "lobby":
            self.session.back_to_lobby()
        else:
            return _bad_request("invalid_phase")
        return web.json_response({"success": True})

    async def session_vote_handler(self, request):
        try:
            data = await _read_json_object(request)
        except BadRequest as e:
            return _bad_request(str(e))
        ok = self.session.vote(str(data.get("deviceId") or ""), data.get("gameId"))
        return web.json_response({"success": ok}, status=200 if ok else 409)

    async def session_play_handler(self, request):
        """Host confirms a game (or the most voted one when none is given)."""
        try:
            data = await _read_json_object(request)
        except BadRequest as e:
            return _bad_request(str(e))
        game_id = data.get("gameId") or self.session.leading_game_id()
        ok = bool(game_id) and self.session.start_countdown(game_id)
        return web.json_response({"success": ok}, status=200 if ok else 409)

    async def session_cancel_countdown_handler(self, request):
        self.session.cancel_countdown()
        return web.json_response({"success": True})

    async def session_stop_game_handler(self, request):
        self.session.stop_game()
        return web.json_response({"success": True})

    async def session_overlay_handler(self, request):
        try:
            data = await _read_json_object(request)
        except BadRequest as e:
            return _bad_request(str(e))
        # Opened by the host (mouse/keyboard): anyone may drive it.
        await self.session.set_overlay(bool(data.get("open")), owner=None)
        return web.json_response({"success": True})

    async def session_overlay_shot_handler(self, request):
        shot = self.session.overlay_shot
        if not shot:
            return web.json_response({"success": False, "code": "no_shot"}, status=404)
        return web.Response(body=shot, content_type="image/jpeg", headers={"Cache-Control": "no-store"})

    async def session_focus_game_handler(self, request):
        focused = await asyncio.to_thread(self.session.focus_game)
        return web.json_response({"success": focused})

    async def session_game_ready_handler(self, request):
        """Host: the game is up (or show the desktop anyway)."""
        self.session.mark_game_ready(reason="host")
        return web.json_response({"success": True})

    async def session_game_window_handler(self, request):
        """The game's window handle, so the desktop can give it the focus
        itself while it is still the foreground app."""
        hwnd = await asyncio.to_thread(self.session.game_window)
        return web.json_response({"hwnd": hwnd})

    async def session_cancel_tournament_handler(self, request):
        self.session.cancel_tournament()
        return web.json_response({"success": True})

    async def session_lobby_zone_handler(self, request):
        """Console lobby: whether a player's face stands in the play area."""
        try:
            data = await _read_json_object(request)
        except BadRequest as e:
            return _bad_request(str(e))
        ok = self.session.set_lobby_zone(str(data.get("deviceId") or ""), data.get("inside") is True)
        return web.json_response({"success": ok})

    async def session_lineup_zone_handler(self, request):
        """Lineup: which side ("play" / "bench") a player's face stands in."""
        try:
            data = await _read_json_object(request)
        except BadRequest as e:
            return _bad_request(str(e))
        zone = data.get("zone")
        ok = self.session.lineup_zone(
            str(data.get("deviceId") or ""), zone if zone in ("play", "bench") else None
        )
        return web.json_response({"success": ok})

    async def session_cancel_lineup_handler(self, request):
        self.session.cancel_lineup()
        return web.json_response({"success": True})

    async def session_tournament_vote_handler(self, request):
        try:
            data = await _read_json_object(request)
        except BadRequest as e:
            return _bad_request(str(e))
        side = data.get("side")
        ok = self.session.tournament_vote(
            str(data.get("deviceId") or ""), side if side in ("a", "b") else None
        )
        return web.json_response({"success": ok})

    async def session_settings_handler(self, request):
        try:
            data = await _read_json_object(request)
        except BadRequest as e:
            return _bad_request(str(e))
        if "matchSeconds" in data:
            try:
                self.session.set_match_seconds(float(data["matchSeconds"]))
            except (TypeError, ValueError):
                return _bad_request("invalid_matchSeconds")
        if "abandonCloseMinutes" in data:
            try:
                self.session.set_abandon_close_minutes(int(data["abandonCloseMinutes"]))
            except (TypeError, ValueError):
                return _bad_request("invalid_abandonCloseMinutes")
        if "freeModeEnabled" in data:
            self.session.set_free_mode_enabled(data["freeModeEnabled"] is True)
        if "mousePassword" in data:
            self.session.mouse_password = str(data["mousePassword"] or "").strip()
        if "lobbyStartRule" in data:
            self.session.set_lobby_start_rule(str(data["lobbyStartRule"]))
        if "consoleMode" in data:
            await self.manager.set_console_mode(data["consoleMode"] is True)
            self.admin_panel.broadcast_update()
        self.session.broadcast()
        return web.json_response({
            "success": True,
            "matchSeconds": self.session.match_seconds,
            "abandonCloseMinutes": self.session.abandon_close_minutes,
            "freeModeEnabled": self.session.free_mode_enabled,
            "consoleMode": self.manager.console_mode,
            "lobbyStartRule": self.session.lobby_start_rule,
            "mousePasswordSet": bool(self.session.mouse_password),
        })

    async def session_free_mode_handler(self, request):
        ok = self.session.enter_free_mode()
        return web.json_response({"success": ok}, status=200 if ok else 409)

    async def session_details_handler(self, request):
        """The desktop resolved a player's Info press over a game."""
        try:
            data = await _read_json_object(request)
        except BadRequest as e:
            return _bad_request(str(e))
        game_id = data.get("gameId")
        ok = self.session.show_details(
            str(data.get("deviceId") or ""), str(game_id) if game_id else None
        )
        return web.json_response({"success": ok}, status=200 if ok else 409)

    async def session_lobby_request_handler(self, request):
        """A player's cursor pressed "back to lobby" on the desktop."""
        try:
            data = await _read_json_object(request)
        except BadRequest as e:
            return _bad_request(str(e))
        ok = self.session.request_lobby(str(data.get("deviceId") or ""))
        return web.json_response({"success": ok}, status=200 if ok else 409)

    async def game_cover_handler(self, request):
        """Cover image of a game, for phones showing its details."""
        game = self.session.library.get(request.match_info.get("game_id", ""))
        path = Path(game.get("coverPath") or "") if game else None
        if not path or not path.is_file():
            return web.json_response({"success": False, "code": "no_cover"}, status=404)
        return web.FileResponse(path, headers={"Cache-Control": "max-age=300"})

    async def session_place_overlay_handler(self, request):
        placed = await self.session.place_overlay_window()
        return web.json_response({"success": placed})

    async def session_switch_game_handler(self, request):
        self.session.switch_game()
        return web.json_response({"success": True})

    async def session_return_handler(self, request):
        """Host is back from an untracked game."""
        self.session.return_from_game()
        return web.json_response({"success": True})

    # -------------------------------------------------------------- games

    def _games_changed(self):
        self.admin_panel.broadcast_event({"type": "games_update", "games": self.session.library.list()})

    async def displays_handler(self, request):
        return web.json_response({"displays": await asyncio.to_thread(list_displays)})

    async def games_handler(self, request):
        return web.json_response({"games": self.session.library.list()})

    async def create_game_handler(self, request):
        try:
            data = await _read_json_object(request)
            game = self.session.library.add(data)
        except (BadRequest, GameValidationError) as e:
            return _bad_request(str(e))
        self._games_changed()
        return web.json_response({"success": True, "game": game})

    async def update_game_handler(self, request):
        try:
            data = await _read_json_object(request)
            game = self.session.library.update(request.match_info["game_id"], data)
        except (BadRequest, GameValidationError) as e:
            return _bad_request(str(e))
        if game is None:
            return web.json_response({"success": False, "code": "not_found"}, status=404)
        self._games_changed()
        return web.json_response({"success": True, "game": game})

    async def delete_game_handler(self, request):
        game_id = request.match_info["game_id"]
        if not self.session.library.delete(game_id):
            return web.json_response({"success": False, "code": "not_found"}, status=404)
        for device_id, voted in list(self.session.votes.items()):
            if voted == game_id:
                self.session.vote(device_id, None)
        self._games_changed()
        return web.json_response({"success": True})

    async def input_mode_handler(self, request):
        try:
            data = await request.json()
        except Exception:
            return web.json_response(
                {"success": False, "error": "Invalid JSON body"},
                status=400
            )

        if not isinstance(data, dict):
            return web.json_response(
                {"success": False, "error": "Request body must be a JSON object"},
                status=400
            )

        mode = data.get("mode")
        if mode not in ("xinput", "dinput"):
            return web.json_response(
                {"success": False, "error": "Invalid input mode"},
                status=400
            )

        internal_mode = "x360" if mode == "xinput" else "ds4"

        try:
            await self.manager.update_server_settings(
                mode=internal_mode,
            )
            self.admin_panel.broadcast_update()
            return web.json_response({
                "success": True,
                "mode": mode
            })
        except Exception as e:
            LOG.error("Failed to update input mode: %s", e)
            return web.json_response(
                {"success": False, "error": str(e)},
                status=500
            )

