import time
from src.models.models import PlayerSlot
from src.core.gamepad_factory import create_gamepad
from src.core.player_identity import normalize_identity
from src.core.controller_presets import ControllerPresetStore

import logging

LOGGER = logging.getLogger(__name__)


class ControllerManager:
    def __init__(self, config):
        self.config = config
        self.slots: list[PlayerSlot] = []
        self.device_map: dict[str, int] = {}
        self.connected_devices: dict[str, dict] = {}
        self.device_colors: dict[str, str] = {}
        self.device_identities: dict[str, dict] = {}
        self.device_ws_map: dict[str, any] = {}
        self.mouse_mode_owner_device_id: str | None = None
        self.main_loop = None
        self.preset_store = ControllerPresetStore()

    def set_main_loop(self, loop):
        self.main_loop = loop

    def initialize_slots(self):
        LOGGER.info("Initializing %d gamepad slots...", self.config.initial_slots)
        for i in range(self.config.initial_slots):
            self._create_empty_slot(i)

    def register_device_ws(self, device_id, ws):
        LOGGER.info("WebSocket connected for device %s", device_id)
        self.device_ws_map[device_id] = ws

    def unregister_device_ws(self, device_id):
        if device_id in self.device_ws_map:
            LOGGER.info("WebSocket disconnected for device %s", device_id)
        self.device_ws_map.pop(device_id, None)

    def get_ws_by_device(self, device_id):
        return self.device_ws_map.get(device_id)

    def notify_device(self, device_id, payload):
        ws = self.get_ws_by_device(device_id)
        if ws:
            import asyncio
            try:
                loop = asyncio.get_running_loop()
                loop.create_task(ws.send_json(payload))
            except Exception:
                LOGGER.exception("Failed to notify device %s", device_id)

    def broadcast_to_devices(self, payload):
        for device_id in list(self.device_ws_map.keys()):
            self.notify_device(device_id, payload)

    def build_active_layout_payload(self):
        preset = self.preset_store.get_active_preset()
        return {
            "type": "layout_preset",
            "controllerMode": getattr(self.config, "controller_type", "x360"),
            "preset": preset,
        }

    def broadcast_active_layout(self):
        LOGGER.info("Broadcasting active layout to all devices")
        self.broadcast_to_devices(self.build_active_layout_payload())

    def cleanup_gamepads(self):
        LOGGER.info("Cleaning up all gamepads...")
        for slot in self.slots:
            try:
                slot.gamepad.reset()
                slot.gamepad.update()
                
                # CRITICAL FIX: Unregister the native callback before destruction
                if hasattr(slot.gamepad, 'unregister_notification'):
                    slot.gamepad.unregister_notification()
                    
            except Exception:
                LOGGER.exception("Error resetting/updating gamepad for slot %s", getattr(slot, 'slot_id', None))

            try:
                del slot.gamepad
            except Exception:
                LOGGER.exception("Error deleting gamepad attribute for slot %s", getattr(slot, 'slot_id', None))

        self.slots.clear()

    def _existing_x360_count(self):
        return sum(
            1 for slot in self.slots
            if slot.controller_type == "x360"
        )
    
    def register_device(self, device_id, player_name=None, customization=None):
        identity = self.update_device_identity(device_id, customization)
        self.connected_devices[device_id] = {
            "deviceId": device_id,
            "name": player_name or device_id,
            "color": identity["color"],
            "faceText": identity["faceText"],
            "faceRotation": identity["faceRotation"],
            "presetId": identity.get("presetId"),
            "connected": True,
        }
        LOGGER.info("Registered device %s name=%s", device_id, player_name)

    def unregister_device(self, device_id):
        self.connected_devices.pop(device_id, None)
        self.release_mouse_mode(device_id)
        LOGGER.info("Unregistered device %s", device_id)

    def _create_empty_slot(self, index):
        gamepad, gp_type = create_gamepad(
            self,
            self.config.controller_type,
            self._existing_x360_count(),
            self.main_loop,
            index,
        )

        slot = PlayerSlot(
            slot_id=index,
            gamepad=gamepad,
            controller_type=gp_type,
        )

        self.slots.append(slot)
        return slot

    def assign_slot(self, device_id, player_name=None):
        if device_id in self.device_map:
            slot_index = self.device_map[device_id]
            slot = self.slots[slot_index]
            slot.connected = True
            slot.player_name = player_name or slot.player_name
            self._apply_identity_to_slot(slot, device_id)
            LOGGER.info("Re-assigned device %s to existing slot %s", device_id, slot.slot_id)
            return slot

        for slot in self.slots:
            if slot.is_available():
                slot.assigned_device_id = device_id
                slot.player_name = player_name
                slot.connected = True
                self._apply_identity_to_slot(slot, device_id)
                self.device_map[device_id] = slot.slot_id
                LOGGER.info("Assigned device %s to available slot %s", device_id, slot.slot_id)
                return slot

        if self.config.auto_expand_slots:
            return self.create_and_assign_new_slot(
                device_id,
                player_name
            )

        return None

    def create_and_assign_new_slot(self, device_id, player_name=None):
        if len(self.slots) >= self.config.max_slots:
            return None

        slot = self._create_empty_slot(len(self.slots))

        slot.assigned_device_id = device_id
        slot.player_name = player_name
        slot.connected = True
        self._apply_identity_to_slot(slot, device_id)

        self.device_map[device_id] = slot.slot_id

        return slot

    def disconnect_slot(self, slot_id):
        slot = self.slots[slot_id]
        slot.connected = False
        if slot.assigned_device_id:
            self.unregister_device_ws(slot.assigned_device_id)
            LOGGER.info("Disconnected device from slot %s", slot_id)
        slot.reserved_until = (
            time.time() +
            self.config.slot_reservation_timeout
        )

    def swap_slots(self, slot_a, slot_b):
        a = self.slots[slot_a]
        b = self.slots[slot_b]

        if a.assigned_device_id is not None and not a.connected and b.assigned_device_id is not None and b.connected:
            self.move_slot(slot_b, slot_a)
            return

        if b.assigned_device_id is not None and not b.connected and a.assigned_device_id is not None and a.connected:
            self.move_slot(slot_a, slot_b)
            return

        LOGGER.info("Swapping assignments between slot %s and slot %s", slot_a, slot_b)

        a.assigned_device_id, b.assigned_device_id = (
            b.assigned_device_id,
            a.assigned_device_id,
        )

        a.player_name, b.player_name = (
            b.player_name,
            a.player_name,
        )

        a.connected, b.connected = b.connected, a.connected

        a.color, b.color = b.color, a.color
        a.face_text, b.face_text = b.face_text, a.face_text
        a.face_rotation, b.face_rotation = b.face_rotation, a.face_rotation
        a.preset_id, b.preset_id = b.preset_id, a.preset_id

        if a.assigned_device_id:
            self.device_map[a.assigned_device_id] = slot_a
            self.notify_device(a.assigned_device_id, {
                "type": "slot_changed",
                "slot": slot_a,
                **self.get_device_identity(a.assigned_device_id),
                "total_slots": len(self.slots)
            })

        if b.assigned_device_id:
            self.device_map[b.assigned_device_id] = slot_b
            self.notify_device(b.assigned_device_id, {
                "type": "slot_changed",
                "slot": slot_b,
                **self.get_device_identity(b.assigned_device_id),
                "total_slots": len(self.slots)
            })

    def assign_to_slot(self, device_id, slot_index, player_name=None):
        if slot_index >= len(self.slots):
            return None
        slot = self.slots[slot_index]
        if slot.connected:
            return None  # already assigned
        
        if slot.assigned_device_id is not None:
            old_id = slot.assigned_device_id
            if old_id in self.device_map:
                del self.device_map[old_id]
            self.notify_device(old_id, {
                "type": "unassigned",
                "total_slots": len(self.slots)
            })
            
        slot.assigned_device_id = device_id
        slot.player_name = player_name or device_id
        slot.connected = True
        self._apply_identity_to_slot(slot, device_id)
        self.device_map[device_id] = slot_index
        LOGGER.info("Manually assigned device %s to slot %s", device_id, slot_index)
        self.notify_device(device_id, {
            "type": "assigned",
            "slot": slot_index,
            **self.get_device_identity(device_id),
            "total_slots": len(self.slots)
        })
        return slot

    def unassign_slot(self, slot_index):
        if slot_index >= len(self.slots):
            return
        slot = self.slots[slot_index]
        if slot.assigned_device_id is not None:
            device_id = slot.assigned_device_id
            LOGGER.info("Unassigned device %s from slot %s", device_id, slot_index)
            slot.connected = False
            slot.assigned_device_id = None
            slot.player_name = None
            slot.color = None
            slot.face_text = ":)"
            slot.face_rotation = "normal"
            slot.preset_id = None
            if device_id in self.device_map:
                del self.device_map[device_id]
            self.notify_device(device_id, {
                "type": "unassigned",
                "total_slots": len(self.slots)
            })

    def get_slot_by_device(self, device_id):
        slot_index = self.device_map.get(device_id)
        if slot_index is None:
            return None
        return self.slots[slot_index]

    def request_mouse_mode(self, device_id):
        if self.mouse_mode_owner_device_id in (None, device_id):
            self.mouse_mode_owner_device_id = device_id
            LOGGER.info("Device %s acquired mouse mode", device_id)
            return True
        return False

    def release_mouse_mode(self, device_id):
        if self.mouse_mode_owner_device_id != device_id:
            return False

        self.mouse_mode_owner_device_id = None
        LOGGER.info("Device %s released mouse mode", device_id)
        return True

    def is_mouse_mode_owner(self, device_id):
        return self.mouse_mode_owner_device_id == device_id

    def get_mouse_mode_owner_name(self):
        owner_id = self.mouse_mode_owner_device_id
        if owner_id is None:
            return None

        device = self.connected_devices.get(owner_id)
        if device is None:
            return None
        return device.get("name") or owner_id

    def build_mouse_mode_payload(self, device_id=None):
        owner_id = self.mouse_mode_owner_device_id
        return {
            "type": "mouse_mode_status",
            "active": owner_id is not None,
            "owner": device_id is not None and owner_id == device_id,
            "ownerName": self.get_mouse_mode_owner_name(),
        }

    def broadcast_mouse_mode_status(self):
        for device_id in list(self.device_ws_map.keys()):
            self.notify_device(device_id, self.build_mouse_mode_payload(device_id))

    def move_slot(self, from_index, to_index):
        if from_index >= len(self.slots) or to_index >= len(self.slots):
            return

        from_slot = self.slots[from_index]
        to_slot = self.slots[to_index]

        if from_slot.assigned_device_id is None:
            return

        LOGGER.info("Moving device %s from slot %s to %s", from_slot.assigned_device_id, from_index, to_index)

        if to_slot.assigned_device_id is not None:
            if to_slot.connected:
                return
            old_id = to_slot.assigned_device_id
            if old_id in self.device_map:
                del self.device_map[old_id]
            self.notify_device(old_id, {
                "type": "unassigned",
                "total_slots": len(self.slots)
            })

        to_slot.assigned_device_id = from_slot.assigned_device_id
        to_slot.player_name = from_slot.player_name
        to_slot.connected = from_slot.connected
        to_slot.color = from_slot.color
        to_slot.face_text = from_slot.face_text
        to_slot.face_rotation = from_slot.face_rotation
        to_slot.preset_id = from_slot.preset_id

        self.device_map[to_slot.assigned_device_id] = to_index

        from_slot.assigned_device_id = None
        from_slot.player_name = None
        from_slot.connected = False
        from_slot.color = None
        from_slot.face_text = ":)"
        from_slot.face_rotation = "normal"
        from_slot.preset_id = None
        
        self.notify_device(to_slot.assigned_device_id, {
            "type": "slot_changed",
            "slot": to_index,
            **self.get_device_identity(to_slot.assigned_device_id),
            "total_slots": len(self.slots)
        })

    def get_connected_devices(self):
        return [
            {
                'deviceId': slot.assigned_device_id,
                'name': slot.player_name or slot.assigned_device_id,
                'connected': slot.connected,
                **self.get_slot_identity(slot),
            }
            for slot in self.slots
            if slot.connected
        ]

    def get_unassigned_devices(self):
        assigned_ids = {
            slot.assigned_device_id
            for slot in self.slots
            if slot.assigned_device_id is not None
        }

        return [
            device
            for device_id, device in self.connected_devices.items()
            if device_id not in assigned_ids
    ]

    def get_slots_state(self):
        return [
            {
                'slot': i,
                'device': {
                    'deviceId': slot.assigned_device_id,
                    'name': slot.player_name or slot.assigned_device_id,
                    'connected': slot.connected,
                    **self.get_slot_identity(slot),
                } if slot.assigned_device_id else None,
                'type': slot.controller_type
            }
            for i, slot in enumerate(self.slots)
        ]
    
    def get_device_color(self, device_id: str) -> str:
        return self.get_device_identity(device_id)["color"]

    def get_device_identity(self, device_id: str) -> dict:
        fallback_color = None
        if device_id in self.device_colors:
            fallback_color = self.device_colors[device_id]
        elif hasattr(self.config, "DEFAULT_COLORS") and self.config.DEFAULT_COLORS:
            index = len(self.device_colors) % len(self.config.DEFAULT_COLORS)
            fallback_color = self.config.DEFAULT_COLORS[index]

        identity = normalize_identity(
            self.device_identities.get(device_id),
            {"color": fallback_color} if fallback_color else None,
        )
        self.device_identities[device_id] = identity
        self.device_colors[device_id] = identity["color"]
        return identity

    def get_slot_identity(self, slot: PlayerSlot) -> dict:
        color = slot.color
        if color is None and slot.assigned_device_id is not None:
            color = self.get_device_color(slot.assigned_device_id)
        return {
            "color": color,
            "faceText": slot.face_text,
            "faceRotation": slot.face_rotation,
            "presetId": slot.preset_id,
        }

    def update_device_identity(self, device_id: str, customization=None) -> dict:
        identity = normalize_identity(
            customization,
            self.device_identities.get(device_id),
        )
        self.device_identities[device_id] = identity
        self.device_colors[device_id] = identity["color"]

        device = self.connected_devices.get(device_id)
        if device is not None:
            device.update({
                "color": identity["color"],
                "faceText": identity["faceText"],
                "faceRotation": identity["faceRotation"],
                "presetId": identity.get("presetId"),
                "connected": True,
            })

        slot = self.get_slot_by_device(device_id)
        if slot is not None:
            self._apply_identity_to_slot(slot, device_id)

        return identity

    def _apply_identity_to_slot(self, slot: PlayerSlot, device_id: str):
        identity = self.get_device_identity(device_id)
        slot.color = identity["color"]
        slot.face_text = identity["faceText"]
        slot.face_rotation = identity["faceRotation"]
        slot.preset_id = identity.get("presetId")

    def update_server_settings(self, mode: str | None = None, slots: int | None = None, fixed: bool | None = None):
        mode_changed = mode is not None and getattr(self.config, 'controller_type', None) != mode

        if fixed is not None:
            self.config.auto_expand_slots = not fixed

        if slots is not None:
            self.config.initial_slots = slots
            self.config.max_slots = slots

        if mode_changed:
            if mode is not None:
                self.config.controller_type = mode
            LOGGER.info("Controller mode changed to %s, recreating gamepads", mode)
            self._recreate_all_gamepads(slots if slots is not None else len(self.slots))
        elif slots is not None:
            LOGGER.info("Resizing slots to %s", slots)
            self._resize_slots(slots)

    def _recreate_all_gamepads(self, new_slot_count: int):

        LOGGER.info(f"Recreating gamepads to {new_slot_count} slots")

        # Save current assignments up to new bounds
        assignments = []
        for i, slot in enumerate(self.slots):
            if i < new_slot_count:
                assignments.append((i, slot.assigned_device_id, slot.player_name))
            else:
                if slot.assigned_device_id:
                    self.unassign_slot(i)

        # Cleanup existing gamepads and slots
        try:
            self.cleanup_gamepads()
        except Exception:
            LOGGER.exception("Error during cleanup_gamepads")

        # Recreate slots in two phases when converting to modes that may be unstable
        # if many devices are created at once (e.g., DS4). Create first up to 4
        # immediately, then create remaining slots sequentially with a short delay.
        first_phase = min(new_slot_count, 4)
        LOGGER.info(f"Creating first phase of gamepads: 0 to {first_phase - 1}")
        for i in range(first_phase):
            self._create_empty_slot(i)

        # Create remaining slots one-by-one with a short pause to avoid driver stress
        LOGGER.info(f"Creating second phase of gamepads: {first_phase} to {new_slot_count - 1}")
        for i in range(first_phase, new_slot_count):
            try:
                time.sleep(0.35)
            except Exception:
                LOGGER.exception("Sleep interrupted while creating gamepads")
            self._create_empty_slot(i)

        # Reassign devices to previous slot indices
        LOGGER.info(f"Reassigning {len(assignments)} devices to new slots")
        for index, device_id, player_name in assignments:
            if device_id:
                try:
                    self.assign_to_slot(device_id, index, player_name)
                except Exception:
                    LOGGER.exception("Failed to reassign device %s to slot %s", device_id, index)

        # Broadcast updates to admin and devices
        try:
            self.broadcast_active_layout()
        except Exception:
            LOGGER.exception("Failed to broadcast active layout")

    def _resize_slots(self, new_size: int):
        current_size = len(self.slots)
        if new_size == current_size:
            return

        if new_size > current_size:
            # Add new slots dynamically
            for i in range(current_size, new_size):
                self._create_empty_slot(i)
            
            # Broadcast the new limit to connected clients incrementally 
            # to avoid disruptive 'assigned' haptics/reconnections.
            for slot in self.slots:
                if slot.assigned_device_id and slot.connected:
                    self.notify_device(slot.assigned_device_id, {
                        "type": "slots_updated",
                        "total_slots": new_size
                    })
        else:
            # Remove excess slots cleanly and return players to pool
            for i in range(new_size, current_size):
                slot = self.slots[i]
                if slot.assigned_device_id:
                    self.unassign_slot(i)
                try:
                    slot.gamepad.reset()
                    slot.gamepad.update()
                    del slot.gamepad
                except Exception:
                    LOGGER.exception("Failed to reset/delete gamepad for slot %s", getattr(slot, 'slot_id', None))
            self.slots = self.slots[:new_size]

            for slot in self.slots:
                if slot.assigned_device_id and slot.connected:
                    self.notify_device(slot.assigned_device_id, {
                        "type": "slots_updated",
                        "total_slots": new_size
                    })
