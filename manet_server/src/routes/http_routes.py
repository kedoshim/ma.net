
from io import BytesIO
import uuid

from aiohttp import web

from src.services.qr_service import generate_qr_code_image
from src.services.connection_service import ConnectionService
from src.services.network_diagnostics_service import NetworkDiagnosticsService
from src.core.slot_handler import notify_device_slot, notify_device_unassigned

import logging
logging.basicConfig(level=logging.INFO)
LOG = logging.getLogger("http_routes")


class HTTPRoutes:
    def __init__(
        self,
        manager,
        admin_panel,
        port,
        ws_endpoint,
        connection_service: ConnectionService,
        diagnostics_service: NetworkDiagnosticsService,
    ):
        self.manager = manager
        self.admin_panel = admin_panel
        self.port = port
        self.ws_endpoint = ws_endpoint
        self.connection_service = connection_service
        self.diagnostics_service = diagnostics_service


    async def server_status_handler(self, request):
        info = self.connection_service.get_connection_info_payload()
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


    async def connection_info_handler(self, request):
        payload = self.connection_service.get_connection_info_payload()
        return web.json_response({
            "success": True,
            "url": payload["url"],
            "wsUrl": payload["wsUrl"],
            "ip": payload["ip"],
            "kind": payload["kind"],
        })


    async def connections_handler(self, request):
        return web.json_response(self.connection_service.get_connections_payload())


    async def diagnostics_handler(self, request):
        return web.json_response(self.diagnostics_service.build_payload())


    async def diagnostics_action_handler(self, request):
        data = await request.json()
        action_id = data.get("actionId")
        if not action_id:
            return web.json_response(
                {"success": False, "code": "missing_action_id"},
                status=400,
            )

        result = self.diagnostics_service.run_action(action_id)
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
            option = self.connection_service.set_preferred_connection(connection_id)
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
        url = self.connection_service.get_qr_url_for_id(connection_id)

        try:
            img = generate_qr_code_image(url)

            buffer = BytesIO()
            img.save(buffer, format="PNG")
            buffer.seek(0)

            return web.Response(
                body=buffer.getvalue(),
                content_type="image/png"
            )
        except Exception as e:
            LOG.error("Failed to generate QR code: %s", e)
            return web.json_response(
                {"success": False, "code": "qr_generation_failed"},
                status=500
            )

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
        preset = self.manager.preset_store.create_custom_preset(payload)
        return web.json_response({"success": True, "preset": preset})

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
        data = await request.json()
        device_id = data['deviceId']
        slot_index = data['slotIndex']
        slot = self.manager.assign_to_slot(device_id, slot_index)
        if slot:
            self.admin_panel.broadcast_update()
            return web.json_response({'success': True})
        else:
            return web.json_response({'success': False}, status=400)


    async def move_handler(self, request):
        data = await request.json()
        from_slot = data['fromSlot']
        to_slot = data['toSlot']
        old_device = self.manager.slots[from_slot].assigned_device_id
        self.manager.move_slot(from_slot, to_slot)
        if old_device:
            await notify_device_slot(self.manager, old_device)
        self.admin_panel.broadcast_update()
        return web.json_response({'success': True})


    async def swap_handler(self, request):
        data = await request.json()
        slot_a = data['slotA']
        slot_b = data['slotB']
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
        data = await request.json()
        slot_index = data['slotIndex']
        device_id = self.manager.slots[slot_index].assigned_device_id
        self.manager.unassign_slot(slot_index)
        await notify_device_unassigned(self.manager, device_id)
        self.admin_panel.broadcast_update()
        return web.json_response({'success': True})

    async def reset_controllers_handler(self, request):
        data = await request.json()
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
            self.manager.update_server_settings(
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
