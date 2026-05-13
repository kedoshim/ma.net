import time
from src.models.models import PlayerSlot
from src.core.gamepad_factory import create_gamepad


class ControllerManager:
    def __init__(self, config):
        self.config = config
        self.slots: list[PlayerSlot] = []
        self.device_map: dict[str, int] = {}
        self.connected_devices: dict[str, dict] = {}
        self.device_colors: dict[str, str] = {}
        self.device_ws_map: dict[str, any] = {}
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
    
    def register_device(self, device_id, player_name=None):
        self.connected_devices[device_id] = {
            "deviceId": device_id,
            "name": player_name or device_id,
            "color": self.get_device_color(device_id)
        }

    def unregister_device(self, device_id):
        self.connected_devices.pop(device_id, None)

    def _create_empty_slot(self, index):
        gamepad, gp_type = create_gamepad(
            self,
            self.config.controller_type,
            self._existing_x360_count(),
            self.main_loop,
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
            return slot

        for slot in self.slots:
            if slot.is_available():
                slot.assigned_device_id = device_id
                slot.player_name = player_name
                slot.connected = True
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

        a.assigned_device_id, b.assigned_device_id = (
            b.assigned_device_id,
            a.assigned_device_id,
        )

        a.player_name, b.player_name = (
            b.player_name,
            a.player_name,
        )

        if a.assigned_device_id:
            self.device_map[a.assigned_device_id] = slot_a
            self.notify_device(a.assigned_device_id, {
                "type": "slot_changed",
                "slot": slot_a,
                "color": self.get_device_color(a.assigned_device_id),
                "total_slots": len(self.slots)
            })

        if b.assigned_device_id:
            self.device_map[b.assigned_device_id] = slot_b
            self.notify_device(b.assigned_device_id, {
                "type": "slot_changed",
                "slot": slot_b,
                "color": self.get_device_color(b.assigned_device_id),
                "total_slots": len(self.slots)
            })

    def assign_to_slot(self, device_id, slot_index, player_name=None):
        if slot_index >= len(self.slots):
            return None
        slot = self.slots[slot_index]
        if slot.connected:
            return None  # already assigned
        slot.assigned_device_id = device_id
        slot.player_name = player_name or device_id
        slot.connected = True
        self.device_map[device_id] = slot_index
        self.notify_device(device_id, {
            "type": "assigned",
            "slot": slot_index,
            "color": self.get_device_color(device_id),
            "total_slots": len(self.slots)
        })
        return slot

    def unassign_slot(self, slot_index):
        if slot_index >= len(self.slots):
            return
        slot = self.slots[slot_index]
        if slot.connected:
            device_id = slot.assigned_device_id
            slot.connected = False
            slot.assigned_device_id = None
            slot.player_name = None
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

    def move_slot(self, from_index, to_index):
        if from_index >= len(self.slots) or to_index >= len(self.slots):
            return

        from_slot = self.slots[from_index]
        to_slot = self.slots[to_index]

        if from_slot.assigned_device_id is None:
            return

        if to_slot.assigned_device_id is not None:
            return

        to_slot.assigned_device_id = from_slot.assigned_device_id
        to_slot.player_name = from_slot.player_name
        to_slot.connected = from_slot.connected

        self.device_map[to_slot.assigned_device_id] = to_index

        from_slot.assigned_device_id = None
        from_slot.player_name = None
        from_slot.connected = False
        
        self.notify_device(to_slot.assigned_device_id, {
            "type": "slot_changed",
            "slot": to_index,
            "color": self.get_device_color(to_slot.assigned_device_id),
            "total_slots": len(self.slots)
        })

    def get_connected_devices(self):
        return [
            {
                'deviceId': slot.assigned_device_id,
                'name': slot.player_name or slot.assigned_device_id,
                'color': self.get_device_color(slot.assigned_device_id)
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
                    'color': self.get_device_color(slot.assigned_device_id),
                } if slot.connected and slot.assigned_device_id else None,
                'type': slot.controller_type
            }
            for i, slot in enumerate(self.slots)
        ]
    
    def get_device_color(self, device_id: str) -> str:
        if device_id not in self.device_colors:
            index = len(self.device_colors) % len(self.config.DEFAULT_COLORS)
            self.device_colors[device_id] = self.config.DEFAULT_COLORS[index]

        return self.device_colors[device_id]