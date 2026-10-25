"""A game that restarts itself (Steam games opened outside Steam) keeps the
session in game instead of sending everyone back to the lobby."""
import time
from types import SimpleNamespace

import pytest

from src.services import game_launcher
from src.services.game_launcher import RunningGame, watch_game

GAME_DIR = r"C:\Steam\steamapps\common\Shipped"
GAME = {"id": "g", "name": "Shipped", "path": GAME_DIR + r"\Shipped.exe"}


@pytest.fixture(autouse=True)
def fast_polls(monkeypatch):
    monkeypatch.setattr(game_launcher, "POLL_INTERVAL_SECONDS", 0.01)
    monkeypatch.setattr(game_launcher, "SUCCESSOR_WAIT_SECONDS", 0.05)


def fake_processes(monkeypatch, procs):
    """procs: list of (pid, exe, create_time), changed in place by the test."""
    def process_iter(attrs):
        return [SimpleNamespace(info={"pid": p, "exe": e, "create_time": c}) for p, e, c in procs]
    monkeypatch.setattr(game_launcher.psutil, "process_iter", process_iter)


def running_game(game=GAME, started_ago=0.0):
    running = RunningGame(game, None, pid=100)
    running.started_at = time.monotonic() - started_ago
    return running


def test_adopts_new_process_from_game_folder(monkeypatch):
    running = running_game()
    fake_processes(monkeypatch, [
        (200, GAME_DIR + r"\Shipped.exe", time.time()),
        (201, r"C:\Steam\steam.exe", time.time()),
        (202, GAME_DIR + r"\Shipped.exe", time.time() - 3600),  # an older copy
    ])
    assert running.adopt_successors() == {200}


def test_shell_launch_adopts_nothing(monkeypatch):
    running = RunningGame({"id": "g", "name": "x", "path": "steam://run/1"}, None)
    fake_processes(monkeypatch, [(200, GAME_DIR + r"\Shipped.exe", time.time())])
    assert running.adopt_successors() == set()


async def test_restart_through_steam_keeps_tracking(monkeypatch):
    # The first exe lives ~15s (past the 10s handoff window), then Steam
    # starts the game again from the same folder; later that copy closes too.
    running = running_game(started_ago=15)
    scans = [[(200, GAME_DIR + r"\Shipped.exe", time.time())]]
    monkeypatch.setattr(game_launcher.psutil, "process_iter", lambda attrs: [
        SimpleNamespace(info={"pid": p, "exe": e, "create_time": c})
        for p, e, c in (scans.pop(0) if scans else [])
    ])
    polls = [set(), {200}, set()]
    monkeypatch.setattr(running, "alive_pids", lambda: polls.pop(0))
    exits = []
    await watch_game(running, lambda handoff: exits.append(handoff))
    assert 200 in running._pids
    assert polls == []  # kept watching the new copy until it closed
    assert exits == [False]


async def test_quick_handoff_without_successor_stays_untracked(monkeypatch):
    running = running_game(started_ago=2)
    fake_processes(monkeypatch, [])
    monkeypatch.setattr(running, "alive_pids", lambda: set())
    exits = []
    await watch_game(running, lambda handoff: exits.append(handoff))
    assert exits == [True]
    assert running.tracked is False


async def test_quitting_after_launch_returns_without_waiting(monkeypatch):
    running = running_game(started_ago=120)
    monkeypatch.setattr(running, "alive_pids", lambda: set())

    def no_scan():
        raise AssertionError("must not look for successors after the launch")
    monkeypatch.setattr(running, "adopt_successors", no_scan)
    exits = []
    await watch_game(running, lambda handoff: exits.append(handoff))
    assert exits == [False]


def test_adopts_processes_in_subfolders(monkeypatch):
    # Unreal-style games run their real exe from Binaries\Win64.
    running = running_game()
    fake_processes(monkeypatch, [
        (200, GAME_DIR + r"\Binaries\Win64\Shipped-Win64-Shipping.exe", time.time()),
        (201, GAME_DIR + r" 2\Other.exe", time.time()),  # a sibling folder
    ])
    assert running.adopt_successors() == {200}


async def test_steam_launch_waits_for_the_game_to_appear(monkeypatch):
    running = RunningGame(GAME, None, folder=GAME_DIR)
    assert running.tracked and not running.has_started()
    scans = [[], [], [(300, GAME_DIR + r"\Shipped.exe", time.time())]]
    monkeypatch.setattr(game_launcher.psutil, "process_iter", lambda attrs: [
        SimpleNamespace(info={"pid": p, "exe": e, "create_time": c})
        for p, e, c in (scans.pop(0) if scans else [])
    ])
    polls = [{300}, set()]
    monkeypatch.setattr(running, "alive_pids", lambda: polls.pop(0))
    running.started_at -= 120  # closing it later returns at once
    exits = []
    await watch_game(running, lambda handoff: exits.append(handoff))
    assert running.has_started()
    assert exits == [False]


async def test_steam_launch_that_never_starts_is_untracked(monkeypatch):
    monkeypatch.setattr(game_launcher, "STEAM_START_SECONDS", 0.05)
    running = RunningGame(GAME, None, folder=GAME_DIR)
    fake_processes(monkeypatch, [])
    exits = []
    await watch_game(running, lambda handoff: exits.append(handoff))
    assert exits == [True]
    assert running.tracked is False
