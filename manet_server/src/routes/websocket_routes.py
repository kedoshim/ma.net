import asyncio
import json
import time

from aiohttp import WSMsgType, web

import logging

from src.input.input_handler import apply_button, apply_stick
from src.input.keyboard_controller import KeyboardController
from src.input.mouse_controller import MouseController
from src.core.slot_handler import reset_slot_gamepad

logging.basicConfig(level=logging.INFO)
LOG = logging.getLogger("websocket")


class WebSocketRoutes:
    def __init__(self, ws_endpoint, manager, admin_panel, connection_service):
        self.manager = manager
        self.admin_panel = admin_panel
        self.ws_endpoint = ws_endpoint
        self.connection_service = connection_service
        self.mouse = MouseController()
        self.keyboard = KeyboardController()

    async def websocket_handler(self, request):
        ws = web.WebSocketResponse()
        await ws.prepare(request)

        peer = request.remote
        sockname = request.transport.get_extra_info("sockname")
        local_ip = sockname[0] if isinstance(sockname, tuple) and sockname else None

        device_id = request.query.get("deviceId")
        player_name = request.query.get("name")
        customization = {
            "color": request.query.get("color"),
            "faceText": request.query.get("faceText"),
            "faceRotation": request.query.get("faceRotation"),
            "presetId": request.query.get("presetId"),
        }

        if not device_id:
            await ws.send_json({
                "type": "error",
                "code": "missing_device_id"
            })
            await ws.close()
            return ws

        self.connection_service.mark_success_for_ip(local_ip)
        self.manager.register_device(device_id, player_name, customization)
        self.manager.register_device_ws(device_id, ws)
        slot = self.manager.assign_slot(device_id, player_name)

        if slot is None:
            await ws.send_json({
                "type": "unassigned",
                "total_slots": len(self.manager.slots),
                **self.manager.get_device_identity(device_id),
            })
            LOG.info("Device %s connected but unassigned (pool)", device_id)
        else:
            slot.connected = True

            LOG.info("Player %d connected (%s)", slot.slot_id + 1, player_name or device_id)
            LOG.info(
                "Assigned slot %s to %s",
                slot.slot_id,
                peer
            )

            await ws.send_json({
                "type": "assigned",
                "slot": slot.slot_id,
                **self.manager.get_slot_identity(slot),
                "total_slots": len(self.manager.slots)
            })

        await ws.send_json(self.manager.build_mouse_mode_payload(device_id))
        await ws.send_json(self.manager.build_active_layout_payload())
        self.admin_panel.broadcast_update()

        try:
            async for msg in ws:
                if msg.type == WSMsgType.ERROR:
                    LOG.error("WS error %s", ws.exception())
                    continue

                if msg.type != WSMsgType.TEXT:
                    continue

                try:
                    data = json.loads(msg.data)
                except Exception:
                    continue

                msg_type = data.get("type")

                current_slot = self.manager.get_slot_by_device(device_id)
                is_mouse_owner = self.manager.is_mouse_mode_owner(device_id)
                if msg_type == "stick":
                    if is_mouse_owner:
                        continue

                    x = float(data.get("x", 0))
                    y = float(data.get("y", 0))

                    if current_slot:
                        current_slot.last_input_at = time.time()
                        current_slot.last_stick_x = x
                        current_slot.last_stick_y = y

                        apply_stick(current_slot, x, y)

                    input_msg = {
                        "type": "input_event",
                        "deviceId": device_id,
                        "event": "stick",
                        "x": x,
                        "y": y
                    }
                    for client in list(self.admin_panel.admin_clients):
                        try:
                            await client.send_json(input_msg)
                        except Exception:
                            pass

                elif msg_type == "button":
                    if is_mouse_owner:
                        continue

                    if current_slot:
                        apply_button(
                            current_slot,
                            data.get("id"),
                            data.get("state"),
                        )
                    
                    input_msg = {
                        "type": "input_event",
                        "deviceId": device_id,
                        "event": "button",
                        "state": data.get("state")
                    }
                    for client in list(self.admin_panel.admin_clients):
                        try:
                            await client.send_json(input_msg)
                        except Exception:
                            pass

                elif msg_type == "keepalive":
                    pass

                elif msg_type == "raw":
                    pass

                elif msg_type == "face_update":
                    self.manager.update_device_identity(device_id, data)
                    self.admin_panel.broadcast_update()
                elif msg_type == "set_mouse_mode":
                    wants_active = data.get("active") == True

                    if wants_active:
                        if not self.manager.request_mouse_mode(device_id):
                            await ws.send_json({
                                "type": "error",
                                "code": "mouse_mode_in_use",
                                "ownerName": self.manager.get_mouse_mode_owner_name(),
                            })
                            continue
                    else:
                        self.manager.release_mouse_mode(device_id)

                    self.manager.broadcast_mouse_mode_status()
                elif msg_type == "mouse_move":
                    if is_mouse_owner:
                        self.mouse.move(
                            float(data.get("x", 0)),
                            -float(data.get("y", 0)),
                        )
                elif msg_type == "mouse_left_down":
                    if is_mouse_owner:
                        self.mouse.left_down()
                elif msg_type == "mouse_left_up":
                    if is_mouse_owner:
                        self.mouse.left_up()
                elif msg_type == "mouse_right_down":
                    if is_mouse_owner:
                        self.mouse.right_down()
                elif msg_type == "mouse_right_up":
                    if is_mouse_owner:
                        self.mouse.right_up()
                elif msg_type == "mouse_scroll":
                    if is_mouse_owner:
                        self.mouse.scroll(float(data.get("delta", 0)))
                elif msg_type == "toggle_window_visibility":
                    if is_mouse_owner:
                        self.admin_panel.broadcast_event({
                            "type": "window_action",
                            "action": "toggle_visibility",
                            "deviceId": device_id,
                        })
                elif msg_type == "quick_action":
                    if is_mouse_owner:
                        action_id = data.get("action")
                        if isinstance(action_id, str):
                            self.keyboard.perform_action(action_id)
                elif msg_type == "rumble_test":
                    LOG.info("Received rumble_test from device %s", device_id)

                    async def _send_pulse():
                        try:
                            await ws.send_json({"type": "rumble", "weak": 0.3, "strong": 0.8})
                            LOG.info("Sent rumble test to %s", device_id)
                            await asyncio.sleep(0.12)
                            await ws.send_json({"type": "rumble", "weak": 0.0, "strong": 0.0})
                            LOG.info("Cleared rumble test for %s", device_id)
                        except Exception:
                            LOG.error("Failed to send rumble_test payload to %s", device_id)

                    asyncio.create_task(_send_pulse())

        except asyncio.CancelledError:
            LOG.debug("Websocket cancelled")

        finally:
            current_slot = self.manager.get_slot_by_device(device_id)
            if current_slot:
                LOG.info("Player %d disconnected", current_slot.slot_id + 1)
                current_slot.last_stick_x = 0
                current_slot.last_stick_y = 0
                current_slot.last_input_at = time.time()
                reset_slot_gamepad(current_slot)
                self.manager.disconnect_slot(current_slot.slot_id)
            else:
                LOG.info("Unassigned device disconnected")

            self.manager.unregister_device(device_id)
            self.manager.unregister_device_ws(device_id)
            self.manager.broadcast_mouse_mode_status()
            self.admin_panel.broadcast_update()

            try:
                await ws.close()
            except Exception:
                pass

        return ws



    async def admin_websocket_handler(self,request):
        ws = web.WebSocketResponse()
        await ws.prepare(request)

        self.admin_panel.admin_clients.add(ws)

        try:
            # send initial state
            pool = self.manager.get_unassigned_devices()
            slots = self.manager.get_slots_state()
            await ws.send_json({
                'type': 'slot_update',
                'data': {
                    'pool': pool,
                    'slots': slots
                }
            })

            async for msg in ws:
                if msg.type == WSMsgType.ERROR:
                    LOG.error("Admin WS error %s", ws.exception())
                # just keep alive

        except asyncio.CancelledError:
            LOG.debug("Admin websocket cancelled")

        finally:
            self.admin_panel.admin_clients.discard(ws)

        return ws
