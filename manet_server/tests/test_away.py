"""Abandoned game: everyone leaves a running game, the overlay opens by
itself, and the game closes unless someone comes back."""
import asyncio
from types import SimpleNamespace

import pytest

from src.core import session_state as ss
from src.core.session_state import SessionPhase, SessionState
from src.models.models import PlayerSlot


class _Manager:
    def __init__(self, seats=2):
        self.slots = [PlayerSlot(slot_id=i, gamepad=None, controller_type="x360") for i in range(seats)]
        self.device_map = {}
        self.device_ws_map = {}
        self.connected_devices = {}
        self.console_mode = False
        self.bench_new_devices = False
        self.hold_reservations = False
        self.config = SimpleNamespace(slot_reservation_timeout=300)
        self.on_device_replaced = None

    def join(self, device_id, seat):
        slot = self.slots[seat]
        slot.assigned_device_id = device_id
        slot.connected = True
        slot.reserved_until = 0
        self.device_map[device_id] = seat
        self.device_ws_map[device_id] = object()

    def leave(self, device_id):
        slot = self.slots[self.device_map[device_id]]
        slot.connected = False
        slot.reserved_until = 1.0  # long expired: only the hold keeps it
        del self.device_ws_map[device_id]

    def unassign_slot(self, index):
        slot = self.slots[index]
        self.device_map.pop(slot.assigned_device_id, None)
        slot.assigned_device_id = None
        slot.connected = False
        slot.reserved_until = 0

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
    def __init__(self):
        self.session = None

    def broadcast_event(self, *args, **kwargs):
        pass

    def broadcast_update(self):
        self.session.sync_players()


class _Running:
    tracked = True

    def __init__(self):
        self.killed = False

    def kill(self):
        self.killed = True

    def to_payload(self):
        return {}


@pytest.fixture
def session(monkeypatch):
    monkeypatch.setattr(ss, "AWAY_GRACE_SECONDS", 0.05)
    monkeypatch.setattr(ss, "capture_game_screen", lambda monitor: None)
    monkeypatch.setattr(SessionState, "_remember_game_window", lambda self, at_home=False: None)
    monkeypatch.setattr(SessionState, "_game_monitor", lambda self: None)
    manager = _Manager()
    admin = _Admin()
    state = SessionState(manager, admin, library=None)
    admin.session = state
    manager.join("a", 0)
    manager.join("b", 1)
    state.phase = SessionPhase.IN_GAME
    state.running = _Running()
    return state


def _everyone_leaves(state):
    for device_id in list(state.manager.device_ws_map):
        state.manager.leave(device_id)
    state.sync_players()


async def _until(condition, timeout=1.0):
    loop = asyncio.get_running_loop()
    end = loop.time() + timeout
    while not condition():
        assert loop.time() < end, "timed out"
        await asyncio.sleep(0.01)


async def test_overlay_opens_after_grace(session):
    _everyone_leaves(session)
    assert session.manager.hold_reservations
    assert not session.away
    await _until(lambda: session.away)
    assert session.overlay_open
    assert session.overlay_owner is None
    assert session.away_close_at is not None


async def test_coming_back_during_grace_cancels(session):
    _everyone_leaves(session)
    session.manager.join("a", 0)
    session.sync_players()
    await asyncio.sleep(0.1)
    assert not session.away
    assert not session.overlay_open
    assert not session.manager.hold_reservations
    # "b" gets a fresh reservation instead of the expired one.
    assert session.manager.slots[1].reserved_until > 1.0


async def test_game_closes_when_nobody_comes_back(session):
    session.abandon_close_minutes = 0.001  # 60 ms
    running = session.running
    _everyone_leaves(session)
    await _until(lambda: session.phase == SessionPhase.LOBBY)
    assert running.killed
    assert not session.away
    assert not session.manager.hold_reservations
    assert all(slot.assigned_device_id is None for slot in session.manager.slots)


async def test_never_close(session):
    session.abandon_close_minutes = 0
    _everyone_leaves(session)
    await _until(lambda: session.away)
    assert session.away_close_at is None
    await asyncio.sleep(0.1)
    assert session.phase == SessionPhase.IN_GAME


async def test_returning_player_pauses_close_and_keeps_seat(session):
    _everyone_leaves(session)
    await _until(lambda: session.away)
    session.manager.join("b", 1)
    session.sync_players()
    assert session.away_close_at is None
    assert session.away
    # "a" is still held, its seat untouched.
    assert session.manager.slots[0].assigned_device_id == "a"
    assert session.manager.hold_reservations


async def test_closing_the_overlay_resumes(session):
    _everyone_leaves(session)
    await _until(lambda: session.away)
    session.manager.join("a", 0)
    session.sync_players()
    await session.set_overlay(False)
    assert not session.away
    assert session.phase == SessionPhase.IN_GAME
    # "b" did not come back yet: usual reservation from now.
    assert not session.manager.hold_reservations
    assert session.manager.slots[1].reserved_until > 1.0


async def test_switch_from_away_goes_to_library(session):
    _everyone_leaves(session)
    await _until(lambda: session.away)
    session.manager.join("a", 0)
    session.sync_players()
    session.switch_game()
    assert session.phase == SessionPhase.LIBRARY
    assert not session.away
    assert not session.manager.hold_reservations


async def test_home_resumes_while_away(session):
    session.game_ready = True
    _everyone_leaves(session)
    await _until(lambda: session.away)
    session.manager.join("a", 0)
    session.sync_players()
    session.handle_home_pressed("a")
    await _until(lambda: not session.overlay_open)
    assert not session.away
