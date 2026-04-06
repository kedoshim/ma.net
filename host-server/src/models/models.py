from dataclasses import dataclass, field
from typing import Optional
import time


@dataclass
class PlayerSlot:
    slot_id: int
    gamepad: object
    controller_type: str

    last_input_at: float = field(default_factory=time.time)
    last_stick_x: float = 0
    last_stick_y: float = 0

    assigned_device_id: Optional[str] = None
    player_name: Optional[str] = None

    ws: Optional[object] = None
    connected: bool = False

    reserved_until: float = 0
    created_at: float = field(default_factory=time.time)

    def is_available(self):
        return self.assigned_device_id is None