"""Seats get the XInput slots in order before a game starts (P2 = slot 1)."""
import asyncio
from types import SimpleNamespace

from src.core import controller_manager as cm
from src.core.controller_manager import ControllerManager
from src.models.models import PlayerSlot


class _Pad:
    def __init__(self, serial):
        self.serial = serial
        self._manet_callback_state = {"alive": True}

    def reset(self):
        pass

    def update(self):
        pass


class _Windows:
    """XInput as Windows runs it: a new pad takes the lowest free slot if
    there is one, and keeps it (or keeps none) until it is unplugged."""

    def __init__(self):
        self.xinput = {}  # id(pad) -> slot
        self.serials = 0

    def plug(self, slot, xinput=None):
        self.serials += 1
        pad = _Pad(self.serials)
        free = [i for i in range(4) if i not in self.xinput.values()]
        if xinput is not None:
            free = [xinput] if xinput in free else []
        if free:
            self.xinput[id(pad)] = free[0]
        slot.gamepad = pad
        slot.controller_type = "x360"
        return True

    def unplug(self, pad):
        self.xinput.pop(id(pad), None)

    def probe(self, states, connected):
        return {key: self.xinput[key] for key in states if key in self.xinput}


def _manager(monkeypatch, windows, seats):
    manager = ControllerManager(SimpleNamespace(controller_type="x360", console_mode=True))
    manager.slots = [PlayerSlot(slot_id=i, gamepad=None, controller_type="x360") for i in range(seats)]
    manager._attach_pad = windows.plug
    monkeypatch.setattr(cm, "xinput_connected_indices", lambda: sorted(windows.xinput.values()))
    monkeypatch.setattr(cm, "probe_xinput_indices", windows.probe)
    monkeypatch.setattr(cm, "retire_gamepad", windows.unplug)
    monkeypatch.setattr(cm, "vigem_serial", lambda pad: pad.serial)
    monkeypatch.setattr(cm, "dinput_serial_order", lambda: list(range(1, windows.serials + 1)))
    return manager


def _xinput_of_seats(manager, windows):
    return [
        None if s.gamepad is None else windows.xinput.get(id(s.gamepad))
        for s in manager.slots
    ]


def test_leftover_pads_from_a_bigger_game_give_their_slots_back(monkeypatch):
    # An 8-player game plugged in a burst: XInput went to P1, P5, P6 and P8.
    windows = _Windows()
    manager = _manager(monkeypatch, windows, 8)
    for seat, xinput in zip(range(8), [0, None, None, None, 1, 2, None, 3]):
        windows.plug(manager.slots[seat], xinput)

    assert asyncio.run(manager.fit_pads_to_game(4))

    assert _xinput_of_seats(manager, windows) == [0, 1, 2, 3, None, None, None, None]


def test_pads_swap_seats_to_follow_the_xinput_slots(monkeypatch):
    windows = _Windows()
    manager = _manager(monkeypatch, windows, 4)
    for seat, xinput in zip(range(4), [2, 0, 3, 1]):
        windows.plug(manager.slots[seat], xinput)
    pads = {id(s.gamepad) for s in manager.slots}

    asyncio.run(manager.fit_pads_to_game(4))

    assert _xinput_of_seats(manager, windows) == [0, 1, 2, 3]
    assert {id(s.gamepad) for s in manager.slots} == pads  # moved, not replugged


def test_pads_past_the_fourth_follow_the_plug_order(monkeypatch):
    windows = _Windows()
    manager = _manager(monkeypatch, windows, 6)

    asyncio.run(manager.fit_pads_to_game(6))

    assert _xinput_of_seats(manager, windows) == [0, 1, 2, 3, None, None]
    assert [s.gamepad.serial for s in manager.slots[4:]] == [5, 6]
