import asyncio
import json
import time

from aiohttp import WSMsgType, web

import logging

from src.input.input_handler import apply_button, apply_stick, apply_right_stick, apply_trigger
from src.input.keyboard_controller import KeyboardController
from src.input.mouse_controller import MouseController
from src.core.slot_handler import reset_slot_gamepad

LOG = logging.getLogger("websocket")

# Ping interval; aiohttp drops the socket when no pong arrives within half of
# it, so a phone that silently left the Wi-Fi is detected in ~15s instead of
# waiting for the OS TCP timeout.
WS_HEARTBEAT_SECONDS = 10.0

# Input flood guard: a phone streams sticks at a few dozen messages per
# second; past this rate messages are dropped, and a socket that keeps it up
# for several seconds is closed.
MAX_MESSAGES_PER_SECOND = 300
MAX_FLOODED_SECONDS = 5

MAX_DEVICE_ID_LENGTH = 64
MAX_NAME_LENGTH = 15
MAX_FIELD_LENGTH = 32


def _clip(value, limit):
    return value[:limit] if isinstance(value, str) else value


class WebSocketRoutes:
    def __init__(self, ws_endpoint, manager, admin_panel, connection_service, session):
        self.manager = manager
        self.admin_panel = admin_panel
        self.session = session
        self.ws_endpoint = ws_endpoint
        self.connection_service = connection_service
        self.mouse = MouseController()
        self.keyboard = KeyboardController()

    def _hotspot_hint(self, reached_ip, port):
        """The PC's own hotspot, when it has one and the phone isn't using it
        (reached_ip: the PC address the phone connected to):
        a direct link is much faster than a crowded router."""
        try:
            snapshot = self.connection_service.get_snapshot()
        except Exception:
            return None
        for option in snapshot.connections:
            if option.kind != "hotspot" or option.ip == reached_ip:
                continue
            parts = option.display_name_key.split("__", 1)
            return {
                "name": parts[1] if len(parts) > 1 else "",
                "url": f"http://{option.ip}:{port}" if port else f"http://{option.ip}",
            }
        return None

    async def websocket_handler(self, request):
        ws = web.WebSocketResponse(heartbeat=WS_HEARTBEAT_SECONDS)
        await ws.prepare(request)

        peer = request.remote
        sockname = request.transport.get_extra_info("sockname")
        local_ip = sockname[0] if isinstance(sockname, tuple) and sockname else None

        device_id = request.query.get("deviceId")
        player_name = _clip(request.query.get("name"), MAX_NAME_LENGTH)
        lang = _clip(request.query.get("lang", "pt"), 8)
        customization = {
            key: _clip(request.query.get(key), MAX_FIELD_LENGTH)
            for key in ("color", "faceText", "faceRotation", "presetId")
        }

        if not device_id or len(device_id) > MAX_DEVICE_ID_LENGTH:
            await ws.send_json({
                "type": "error",
                "code": "missing_device_id"
            })
            await ws.close()
            return ws

        self.connection_service.mark_success_for_ip(local_ip)
        self.manager.register_device(device_id, player_name, customization, lang=lang)
        resolved_name = self.manager.connected_devices[device_id]["name"]
        previous_ws = self.manager.register_device_ws(device_id, ws)
        if previous_ws is not None:
            # Same phone reconnected before its old socket noticed it was dead.
            # Close the stale one; its cleanup will see it is no longer current.
            LOG.info("Device %s reconnected; closing stale socket", device_id)
            asyncio.create_task(previous_ws.close())
        slot = self.manager.assign_slot(device_id, resolved_name)

        if slot is None:
            await ws.send_json({
                "type": "unassigned",
                "total_slots": len(self.manager.slots),
                "name": resolved_name,
                **self.manager.get_device_identity(device_id),
            })
            LOG.info("Device %s (%s) connected but unassigned (pool)", device_id, resolved_name)
        else:
            slot.connected = True

            LOG.info("Player connected")
            LOG.info("Player %d connected (%s)", slot.slot_id + 1, resolved_name)
            LOG.info(
                "Assigned slot %s (%s) to %s",
                slot.slot_id,
                resolved_name,
                peer
            )

            await ws.send_json({
                "type": "assigned",
                "slot": slot.slot_id,
                "name": resolved_name,
                **self.manager.get_slot_identity(slot),
                "total_slots": len(self.manager.slots)
            })

        await ws.send_json(self.manager.build_mouse_mode_payload(device_id))
        await ws.send_json(self.manager.build_active_layout_payload())
        phone_state = self.session.phone_payload(device_id)
        self.session._last_phone_payloads[device_id] = phone_state
        await ws.send_json(phone_state)
        await ws.send_json({
            "type": "slot_status",
            "has_vacant_slot": self.manager.has_vacant_slot(),
        })
        # A browser on the MaNet PC itself also sees MaNet's virtual pads, so
        # the physical-pad relay must not offer itself automatically there.
        await ws.send_json({
            "type": "client_info",
            "sameMachine": peer is not None and (peer == local_ip or peer in ("127.0.0.1", "::1")),
        })
        self.admin_panel.broadcast_update()

        # Relayed analog triggers, as pressed/released for menus and the admin feed.
        trigger_down = {"LT": False, "RT": False}

        rate_window = int(time.monotonic())
        rate_count = 0
        flooded_seconds = 0

        try:
            async for msg in ws:
                if msg.type == WSMsgType.ERROR:
                    LOG.error("WS error %s", ws.exception())
                    continue

                if msg.type != WSMsgType.TEXT:
                    continue

                now_window = int(time.monotonic())
                if now_window != rate_window:
                    flooded = rate_count > MAX_MESSAGES_PER_SECOND
                    if not flooded or now_window - rate_window > 1:
                        flooded_seconds = 0
                    if flooded:
                        flooded_seconds += 1
                    rate_window = now_window
                    rate_count = 0
                rate_count += 1
                if rate_count > MAX_MESSAGES_PER_SECOND:
                    if flooded_seconds >= MAX_FLOODED_SECONDS:
                        LOG.warning("Device %s flooding input; closing socket", device_id)
                        break
                    continue

                try:
                    data = json.loads(msg.data)
                except Exception:
                    continue
                if not isinstance(data, dict):
                    continue

                try:
                    msg_type = data.get("type")

                    current_slot = self.manager.get_slot_by_device(device_id)
                    is_mouse_owner = self.manager.is_mouse_mode_owner(device_id)

                    to_game = current_slot is not None and self.session.routes_to_game()

                    if msg_type == "stick":
                        if is_mouse_owner:
                            continue

                        x = float(data.get("x", 0))
                        y = float(data.get("y", 0))

                        if to_game:
                            current_slot.last_input_at = time.time()
                            current_slot.last_stick_x = x
                            current_slot.last_stick_y = y
                            apply_stick(current_slot, x, y)

                        self.admin_panel.broadcast_input({
                            "type": "input_event",
                            "deviceId": device_id,
                            "event": "stick",
                            "x": x,
                            "y": y
                        })

                    elif msg_type == "rstick":
                        if is_mouse_owner:
                            continue

                        x = float(data.get("x", 0))
                        y = float(data.get("y", 0))

                        if to_game:
                            current_slot.last_input_at = time.time()
                            current_slot.last_rstick_x = x
                            current_slot.last_rstick_y = y
                            apply_right_stick(current_slot, x, y)

                        self.admin_panel.broadcast_input({
                            "type": "input_event",
                            "deviceId": device_id,
                            "event": "rstick",
                            "x": x,
                            "y": y
                        })

                    elif msg_type == "button":
                        if is_mouse_owner:
                            continue

                        if to_game:
                            apply_button(
                                current_slot,
                                data.get("id"),
                                data.get("state"),
                            )
                        elif current_slot is not None:
                            self.session.handle_menu_button(
                                device_id,
                                data.get("id"),
                                data.get("state"),
                            )

                        self.admin_panel.broadcast_input({
                            "type": "input_event",
                            "deviceId": device_id,
                            "event": "button",
                            "id": data.get("id"),
                            "state": data.get("state")
                        })

                    elif msg_type == "trigger":
                        # Analog LT/RT from a physical pad relayed by the phone.
                        if is_mouse_owner:
                            continue

                        btn = data.get("id")
                        if btn not in trigger_down:
                            continue
                        value = float(data.get("value", 0))

                        if to_game:
                            current_slot.last_input_at = time.time()
                            apply_trigger(current_slot, btn, value)

                        pressed = value > (0.3 if trigger_down[btn] else 0.5)
                        if pressed != trigger_down[btn]:
                            trigger_down[btn] = pressed
                            state = "down" if pressed else "up"
                            if not to_game and current_slot is not None:
                                self.session.handle_menu_button(device_id, btn, state)
                            self.admin_panel.broadcast_input({
                                "type": "input_event",
                                "deviceId": device_id,
                                "event": "button",
                                "id": btn,
                                "state": state,
                            })

                    elif msg_type == "home_pressed":
                        self.session.handle_home_pressed(device_id)

                    elif msg_type == "keepalive":
                        pass

                    elif msg_type == "ping":
                        # The phone measures its round trip (lag warning).
                        await ws.send_json({"type": "pong", "t": data.get("t")})

                    elif msg_type == "network_hint":
                        hint = await asyncio.to_thread(
                            self._hotspot_hint, local_ip, sockname[1] if isinstance(sockname, tuple) else None
                        )
                        await ws.send_json({"type": "network_hint", "hotspot": hint})

                    elif msg_type == "raw":
                        pass

                    elif msg_type == "face_update":
                        self.manager.update_device_identity(device_id, data)
                        self.admin_panel.broadcast_update()
                    elif msg_type == "name_update":
                        new_name = data.get("name")
                        if new_name:
                            new_name = new_name[:15]
                            self.manager.update_player_name(device_id, new_name)
                            self.admin_panel.broadcast_update()
                    elif msg_type == "request_random_name":
                        from src.core.name_generator import NameGenerator
                        random_name = NameGenerator.generate("pt")
                        await ws.send_json({
                            "type": "random_name_response",
                            "name": random_name
                        })
                    elif msg_type == "set_mouse_mode":
                        wants_active = data.get("active") == True

                        if wants_active:
                            denied = self.session.mouse_mode_check(data.get("password"))
                            if denied is not None:
                                await ws.send_json({"type": "error", "code": denied})
                                continue
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

                    elif msg_type == "seat_bench":
                        self.session.go_to_bench(device_id)
                    elif msg_type == "seat_join":
                        self.session.join_from_bench(device_id)
                    elif msg_type == "check_in":
                        self.session.check_in(device_id)
                    elif msg_type == "check_out":
                        self.session.check_out(device_id)
                    elif msg_type == "lineup_pick":
                        self.session.lineup_pick(device_id, data.get("value"))
                    elif msg_type == "seat_move":
                        try:
                            seat = int(data.get("slot"))
                        except (TypeError, ValueError):
                            seat = -1
                        self.session.move_to_seat(device_id, seat)
                    elif msg_type == "swap_request":
                        self.session.request_swap(device_id, str(data.get("target") or ""))
                    elif msg_type == "swap_answer":
                        self.session.answer_swap(
                            device_id, str(data.get("from") or ""), data.get("accept") is True
                        )
                    elif msg_type == "lobby_request":
                        self.session.request_lobby(device_id)
                    elif msg_type == "lobby_answer":
                        self.session.answer_lobby(device_id, data.get("accept") is True)
                    elif msg_type == "details_close":
                        self.session.show_details(device_id, None)
                    elif msg_type == "request_slot":
                        # (During a console game assign_slot keeps them on the
                        # bench: they join from the overlay's seat list.)
                        dev_name = self.manager.connected_devices.get(device_id, {}).get("name", player_name)
                        LOG.info("Device %s (%s) requested slot", device_id, dev_name)
                        slot = self.manager.assign_slot(device_id, dev_name)
                        if slot is not None:
                            slot.connected = True
                            await ws.send_json({
                                "type": "assigned",
                                "slot": slot.slot_id,
                                "name": slot.player_name,
                                **self.manager.get_slot_identity(slot),
                                "total_slots": len(self.manager.slots)
                            })
                        else:
                            await ws.send_json({
                                "type": "unassigned",
                                "total_slots": len(self.manager.slots),
                                "name": dev_name,
                                **self.manager.get_device_identity(device_id),
                            })
                        self.admin_panel.broadcast_update()
                except Exception as ex:
                    LOG.exception("Exception during processing message: %s", msg.data)

        except asyncio.CancelledError:
            LOG.debug("Websocket cancelled")

        finally:
            if not self.manager.is_current_device_ws(device_id, ws):
                # A newer socket from the same phone took over; leave its
                # slot, registration and mouse mode untouched.
                LOG.info("Stale socket for device %s closed", device_id)
                try:
                    await ws.close()
                except Exception:
                    pass
                return ws

            current_slot = self.manager.get_slot_by_device(device_id)
            dev_name = self.manager.connected_devices.get(device_id, {}).get("name")
            if current_slot:
                LOG.info("Player %d (%s) disconnected", current_slot.slot_id + 1, current_slot.player_name)
                current_slot.last_stick_x = 0
                current_slot.last_stick_y = 0
                current_slot.last_rstick_x = 0
                current_slot.last_rstick_y = 0
                current_slot.last_input_at = time.time()
                reset_slot_gamepad(current_slot)
                self.manager.disconnect_slot(current_slot.slot_id)
            else:
                LOG.info("Unassigned device %s (%s) disconnected", device_id, dev_name or "unknown")

            self.manager.unregister_device(device_id)
            self.manager.unregister_device_ws(device_id, ws)
            self.admin_panel.forget_device(device_id)
            self.manager.broadcast_mouse_mode_status()
            self.admin_panel.broadcast_update()

            try:
                await ws.close()
            except Exception:
                pass

        return ws



    async def admin_websocket_handler(self,request):
        ws = web.WebSocketResponse(heartbeat=WS_HEARTBEAT_SECONDS)
        await ws.prepare(request)

        try:
            # send initial state before joining broadcasts so ordering holds
            pool = self.manager.get_unassigned_devices()
            slots = self.manager.get_slots_state()
            await ws.send_json({
                'type': 'slot_update',
                'data': {
                    'pool': pool,
                    'slots': slots
                }
            })
            await ws.send_json(self.session.to_payload())
            self.admin_panel.add_client(ws)

            async for msg in ws:
                if msg.type == WSMsgType.ERROR:
                    LOG.error("Admin WS error %s", ws.exception())
                # just keep alive

        except asyncio.CancelledError:
            LOG.debug("Admin websocket cancelled")

        finally:
            self.admin_panel.remove_client(ws)

        return ws
