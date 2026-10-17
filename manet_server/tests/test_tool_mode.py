"""Tool mode: MaNet stays out of the way, phones are plain gamepads."""
from types import SimpleNamespace

import pytest

from src.core.session_state import InputMode, SessionPhase, SessionState
from src.models.models import PlayerSlot


class _Manager:
    def __init__(self, console):
        self.slots = [PlayerSlot(slot_id=i, gamepad=None, controller_type="x360") for i in range(2)]
        self.device_map = {}
        self.device_ws_map = {}
        self.connected_devices = {}
        self.console_mode = console
        self.bench_new_devices = False
        self.hold_reservations = False
        self.config = SimpleNamespace(slot_reservation_timeout=300)
        self.on_device_replaced = None
        for seat, device_id in enumerate(["a", "b"]):
            slot = self.slots[seat]
            slot.assigned_device_id = device_id
            slot.connected = True
            self.device_map[device_id] = seat
            self.device_ws_map[device_id] = object()

    def get_device_identity(self, device_id):
        return {}

    def get_slot_by_device(self, device_id):
        index = self.device_map.get(device_id)
        return None if index is None else self.slots[index]

    def pulse_device(self, *args, **kwargs):
        pass

    def notify_device(self, *args, **kwargs):
        pass

    def needs_pads(self):
        return False


class _Admin:
    def broadcast_event(self, *args, **kwargs):
        pass


def _session(console):
    state = SessionState(_Manager(console), _Admin(), library=None)
    state.broadcast()
    return state


def test_tool_mode_lobby_leaves_the_phones_as_gamepads():
    state = _session(console=False)
    assert state.phase == SessionPhase.LOBBY
    assert state.input_mode == InputMode.GAME
    assert state.phone_payload("a")["menu"] is False


def test_console_mode_lobby_owns_the_phones():
    state = _session(console=True)
    assert state.input_mode == InputMode.MENU
    assert state.phone_payload("a")["menu"] is True


def test_switching_to_tool_mode_releases_the_phones():
    state = _session(console=True)
    state.manager.console_mode = False
    state.broadcast()
    assert state.input_mode == InputMode.GAME


@pytest.mark.asyncio
async def test_tool_mode_never_counts_down_to_the_library():
    state = _session(console=False)
    state.ready.update({"a", "b"})
    state._check_lobby_countdown()
    assert state.lobby_countdown_ends_at is None
    assert state.phase == SessionPhase.LOBBY


def test_the_host_can_still_open_the_library_by_hand():
    state = _session(console=False)
    state.enter_library()
    assert state.phase == SessionPhase.LIBRARY
    assert state.input_mode == InputMode.MENU
