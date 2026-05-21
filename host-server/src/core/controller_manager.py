import time
from src.models.models import PlayerSlot
from src.core.gamepad_factory import create_gamepad
from src.core.player_identity import normalize_identity


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

    def set_main_loop(self, loop):
        self.main_loop = loop

    def initialize_slots(self):
        for i in range(self.config.initial_slots):
            self._create_empty_slot(i)

    def register_device_ws(self, device_id, ws):
        self.device_ws_map[device_id] = ws


    def unregister_device_ws(self, device_id):
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
                pass

    def broadcast_to_devices(self, payload):
        for device_id in list(self.device_ws_map.keys()):
            self.notify_device(device_id, payload)

    def cleanup_gamepads(self):
        for slot in self.slots:
            try:
                slot.gamepad.reset()
                slot.gamepad.update()
            except Exception:
                pass

            try:
                del slot.gamepad
            except Exception:
                pass

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

    def unregister_device(self, device_id):
        self.connected_devices.pop(device_id, None)
        self.release_mouse_mode(device_id)

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
            return slot

        for slot in self.slots:
            if slot.is_available():
                slot.assigned_device_id = device_id
                slot.player_name = player_name
                slot.connected = True
                self._apply_identity_to_slot(slot, device_id)
                self.device_map[device_id] = slot.slot_id
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
            return True
        return False

    def release_mouse_mode(self, device_id):
        if self.mouse_mode_owner_device_id != device_id:
            return False

        self.mouse_mode_owner_device_id = None
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
