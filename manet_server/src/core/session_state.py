"""
Session state: the server-side source of truth for what the whole couch is
doing. Desktop and phones render it and send intents; they never own it.

    lobby ──(everyone ready + START)──> library ──(votes + countdown)──> in_game
      ^                                    │                                │
      └──────────(SELECT / host)───────────┘<──────(game exits / host)──────┘

Input routing: while the MaNet window has focus in the lobby or the library,
phone input drives MaNet (ready toggles, cursors, votes) and never reaches
the virtual gamepads. Otherwise (a game in front, or MaNet in the
background) input goes to the gamepads as usual.
"""
import asyncio
import logging
import random
import time
from enum import Enum

from src.core.slot_handler import reset_slot_gamepad
from src.core.game_library import resolve_settings
from src.core.tournament import (
    ALL_VOTED_GRACE_SECONDS,
    CHAMPION_SECONDS,
    INTRO_SECONDS,
    MATCH_SECONDS_DEFAULT,
    RESULT_SECONDS,
    Tournament,
)
from src.services.game_launcher import LaunchError, RunningGame, start_game, watch_game
from src.services.window_placement import (
    capture_game_screen,
    enforce_placement,
    foreground_pid,
    game_monitor,
    move_to_monitor,
)

LOGGER = logging.getLogger(__name__)

COUNTDOWN_SECONDS = 3.0


class SessionPhase(str, Enum):
    LOBBY = "lobby"
    LIBRARY = "library"
    # Elimination tournament between the games voted in the library.
    TOURNAMENT = "tournament"
    IN_GAME = "in_game"


MENU_PHASES = (SessionPhase.LOBBY, SessionPhase.LIBRARY, SessionPhase.TOURNAMENT)


class InputMode(str, Enum):
    # Phone input drives the virtual gamepad (normal play).
    GAME = "game"
    # Phone input drives MaNet menus/cursors and never reaches the game.
    MENU = "menu"
    # A MaNet-launched game is running but another window is in front:
    # input reaches nothing, so it can't leak into other games/apps.
    PAUSED = "paused"


# How long a "trade places?" request waits for an answer.
SWAP_OFFER_SECONDS = 20.0

# How often the running game's foreground status is checked.
FOREGROUND_POLL_SECONDS = 0.3


class SessionState:
    def __init__(self, manager, admin_panel, library):
        self.manager = manager
        self.admin_panel = admin_panel
        self.library = library
        self.phase = SessionPhase.LOBBY
        self.focused = False
        self.input_mode = InputMode.GAME
        # Keyed by deviceId: slots can be reshuffled while a player stays.
        self.ready: set[str] = set()
        self.votes: dict[str, str] = {}
        self.countdown_game_id: str | None = None
        self.countdown_ends_at: float | None = None
        self._countdown_task: asyncio.Task | None = None
        self.running: RunningGame | None = None
        self._watch_task: asyncio.Task | None = None
        self._placement_task: asyncio.Task | None = None
        self.last_error: str | None = None
        self.overlay_open = False
        # Only the player who opened the overlay drives it (None: anyone,
        # e.g. after the opener disconnected or the host opened it).
        self.overlay_owner: str | None = None
        self.overlay_monitor: dict | None = None
        self.overlay_shot: bytes | None = None
        self.overlay_shot_id = 0
        self.game_in_front = True
        self._guard_task: asyncio.Task | None = None
        self._last_phone_payloads: dict[str, dict] = {}
        # target deviceId -> (requesting deviceId, expiry timestamp)
        self._swap_offers: dict[str, tuple[str, float]] = {}
        self.tournament: Tournament | None = None
        self._tournament_task: asyncio.Task | None = None
        self.match_seconds = MATCH_SECONDS_DEFAULT

    # ---------------------------------------------------------------- players

    def player_ids(self) -> list[str]:
        """Devices playing right now: assigned to a slot and connected."""
        return [
            slot.assigned_device_id
            for slot in self.manager.slots
            if slot.assigned_device_id and slot.connected
        ]

    def all_ready(self) -> bool:
        players = self.player_ids()
        return bool(players) and all(p in self.ready for p in players)

    def sync_players(self):
        """Drop state of players who left; re-check votes. Called whenever
        slots change."""
        players = set(self.player_ids())
        changed = False
        for device_id in list(self.ready):
            if device_id not in players:
                self.ready.discard(device_id)
                changed = True
        for device_id in list(self.votes):
            if device_id not in players:
                del self.votes[device_id]
                changed = True
        if changed and self.phase == SessionPhase.LIBRARY:
            self._votes_changed()
        if self.tournament is not None:
            self.tournament.drop_voters(players)
        if self.overlay_owner is not None and self.overlay_owner not in players:
            # The opener left; let anyone drive the overlay so it can't get stuck.
            self.overlay_owner = None
        # Always publish: a player joining changes "everyone ready" too.
        self.broadcast()

    # ------------------------------------------------------------ input mode

    def routes_to_game(self) -> bool:
        return self.input_mode == InputMode.GAME

    def _refresh_input_mode(self):
        menu = self.overlay_open or (self.focused and self.phase in MENU_PHASES)
        if menu:
            mode = InputMode.MENU
        elif self.phase == SessionPhase.IN_GAME and not self.game_in_front:
            mode = InputMode.PAUSED
        else:
            mode = InputMode.GAME
        if mode == self.input_mode:
            return
        self.input_mode = mode
        LOGGER.info("Input mode -> %s", mode.value)
        if mode != InputMode.GAME:
            # Whatever was held when the game lost the input must not stay
            # stuck pressed on the virtual pads.
            for slot in self.manager.slots:
                slot.last_stick_x = slot.last_stick_y = 0
                slot.last_rstick_x = slot.last_rstick_y = 0
                reset_slot_gamepad(slot)

    def set_focus(self, focused: bool):
        if self.focused == focused:
            return
        self.focused = focused
        self._refresh_input_mode()
        self.broadcast()

    # ------------------------------------------------------------- buttons

    def handle_menu_button(self, device_id: str, button: str, state: str):
        """Button pressed by a player while input drives MaNet. Cursor clicks
        (A) are resolved by the desktop, which knows where each cursor is."""
        if state != "down" or device_id not in self.player_ids():
            return
        # Menus use a game-independent scheme: Select (A) and Back (B); the
        # console-style START/SELECT keep working too.
        if self.phase == SessionPhase.LOBBY:
            if button in ("A", "START"):
                if device_id not in self.ready:
                    self.ready.add(device_id)
                    self.manager.pulse_device(device_id)
                    self.broadcast()
                elif self.all_ready():
                    self.enter_library()
            elif button == "B" and device_id in self.ready:
                self.ready.discard(device_id)
                self.broadcast()
        elif self.phase == SessionPhase.LIBRARY:
            # B (Back) is resolved by the desktop, which knows whether it
            # should close the game details panel, remove the vote or leave.
            if button == "SELECT":
                self.back_to_lobby()
            elif button == "START" and self.countdown_game_id is None:
                self.decide()

    def handle_home_pressed(self, device_id: str):
        """A phone's Home button toggles the in-game overlay."""
        if self.phase != SessionPhase.IN_GAME or device_id not in self.player_ids():
            return
        if self.overlay_open and self.overlay_owner not in (None, device_id):
            return  # someone else is using the overlay
        LOGGER.info("Home pressed by device %s", device_id)
        self.manager.pulse_device(device_id)
        asyncio.get_running_loop().create_task(
            self.set_overlay(not self.overlay_open, owner=device_id)
        )

    # ------------------------------------------------------------- overlay

    async def set_overlay(self, open_: bool, owner: str | None = None):
        """Show/hide the overlay over the running game. While it is open,
        phone input drives the overlay menu and never reaches the game."""
        if self.phase != SessionPhase.IN_GAME:
            open_ = False
        if open_ == self.overlay_open:
            return
        if open_:
            pids = self._game_pids()
            self.overlay_monitor = await asyncio.to_thread(game_monitor, pids)
            try:
                shot = await asyncio.to_thread(capture_game_screen, self.overlay_monitor)
            except Exception:
                LOGGER.exception("Could not capture the game screen")
                shot = None
            self.overlay_shot = shot
            self.overlay_shot_id += 1
        self.overlay_owner = owner if open_ else None
        self.overlay_open = open_
        self._refresh_input_mode()
        self.broadcast()

    def _game_pids(self) -> set[int]:
        return self.running.alive_pids() if self.running and self.running.tracked else set()

    async def place_overlay_window(self) -> bool:
        """Move MaNet's window onto the game's monitor (called by the desktop
        right before it goes full screen for the overlay)."""
        desktop_pid = getattr(self.manager.config, "parent_pid", None)
        if not desktop_pid or not self.overlay_monitor:
            return False
        return await asyncio.to_thread(move_to_monitor, desktop_pid, self.overlay_monitor)

    async def _guard_foreground(self):
        """While a tracked game runs, input only reaches the virtual pads
        when that game is the foreground window."""
        try:
            while self.phase == SessionPhase.IN_GAME and self.running is not None:
                await asyncio.sleep(FOREGROUND_POLL_SECONDS)
                if not self.running.tracked:
                    # Handed off to a launcher: we can't tell which window
                    # is the game any more, so stop guarding.
                    if not self.game_in_front:
                        self.game_in_front = True
                        self._refresh_input_mode()
                        self.broadcast()
                    return
                pid = await asyncio.to_thread(foreground_pid)
                pids = await asyncio.to_thread(self._game_pids)
                in_front = pid is None or pid in pids
                if in_front != self.game_in_front:
                    self.game_in_front = in_front
                    LOGGER.info("Game %s the foreground window", "is" if in_front else "is not")
                    self._refresh_input_mode()
                    self.broadcast()
        except asyncio.CancelledError:
            pass

    def switch_game(self):
        """Close the running game and go pick another one."""
        self.stop_game()
        self.enter_library()

    # -------------------------------------------------------------- phases

    def _set_phase(self, phase: SessionPhase):
        self.phase = phase
        self._refresh_input_mode()

    def enter_library(self):
        if self.phase != SessionPhase.LOBBY:
            return
        LOGGER.info("Entering game library")
        self.votes.clear()
        self.last_error = None
        self._set_phase(SessionPhase.LIBRARY)
        for device_id in self.player_ids():
            self.manager.pulse_device(device_id)
        self.broadcast()

    def back_to_lobby(self):
        if self.phase == SessionPhase.IN_GAME:
            return
        self._stop_tournament()
        self.cancel_countdown(broadcast=False)
        self.votes.clear()
        self.ready.clear()
        self._set_phase(SessionPhase.LOBBY)
        self.broadcast()

    # --------------------------------------------------------------- votes

    def vote(self, device_id: str, game_id: str | None):
        if self.phase != SessionPhase.LIBRARY or device_id not in self.player_ids():
            return False
        if game_id is not None:
            game = self.library.get(game_id)
            players = len(self.player_ids())
            # Players can only vote for games that fit everyone; the host can
            # still force any game with a click.
            if game is None or not game["minPlayers"] <= players <= game["maxPlayers"]:
                return False
        previous = self.votes.get(device_id)
        if game_id is None:
            self.votes.pop(device_id, None)
        else:
            self.votes[device_id] = game_id
        if previous != game_id:
            self.manager.pulse_device(device_id)
            self._votes_changed()
            self.broadcast()
        return True

    def leading_game_id(self) -> str | None:
        counts: dict[str, int] = {}
        for game_id in self.votes.values():
            counts[game_id] = counts.get(game_id, 0) + 1
        if not counts:
            return None
        best = max(counts.values())
        return random.choice(sorted(g for g, c in counts.items() if c == best))

    def _votes_changed(self):
        # Any change restarts the decision; when everyone has voted the most
        # voted game (ties drawn at random) gets a countdown.
        self.cancel_countdown(broadcast=False)
        players = self.player_ids()
        if players and all(p in self.votes for p in players):
            self.decide(broadcast=False)

    def decide(self, broadcast: bool = True):
        """Everyone picked (or someone pressed START): one candidate gets a
        countdown; several play an elimination tournament."""
        candidates = set(self.votes.values())
        if len(candidates) >= 2:
            self.start_tournament()
        elif candidates:
            self.start_countdown(next(iter(candidates)), broadcast=broadcast)

    # ---------------------------------------------------------- tournament

    def start_tournament(self) -> bool:
        if self.phase != SessionPhase.LIBRARY:
            return False
        counts: dict[str, int] = {}
        for game_id in self.votes.values():
            counts[game_id] = counts.get(game_id, 0) + 1
        if len(counts) < 2:
            return False
        self.cancel_countdown(broadcast=False)
        self.tournament = Tournament(counts)
        LOGGER.info("Tournament between %d games", len(counts))
        self._set_phase(SessionPhase.TOURNAMENT)
        self._tournament_task = asyncio.get_running_loop().create_task(self._run_tournament())
        self.broadcast()
        return True

    def _stop_tournament(self):
        if self._tournament_task is not None:
            self._tournament_task.cancel()
        self._tournament_task = None
        self.tournament = None

    def cancel_tournament(self):
        """Back to the library with the votes kept."""
        if self.phase != SessionPhase.TOURNAMENT:
            return
        self._stop_tournament()
        self._set_phase(SessionPhase.LIBRARY)
        self.broadcast()

    def tournament_vote(self, device_id: str, side: str | None) -> bool:
        """The desktop reports which half of the screen each player's
        cursor is in (None: the middle strip)."""
        t = self.tournament
        if t is None or device_id not in self.player_ids():
            return False
        if not t.vote(device_id, side):
            return False
        if side is not None:
            self.manager.pulse_device(device_id, strong=0.3, weak=0.2, seconds=0.05)
        players = set(self.player_ids())
        if t.ends_at and all(p in t.votes for p in players):
            # Everyone chose: don't make them wait out the clock.
            t.ends_at = min(t.ends_at, time.time() + ALL_VOTED_GRACE_SECONDS)
        self.broadcast()
        return True

    async def _run_tournament(self):
        t = self.tournament
        try:
            t.stage = "intro"
            self.broadcast()
            await asyncio.sleep(INTRO_SECONDS)
            while t.next_match() is not None:
                t.stage = "match"
                t.ends_at = time.time() + self.match_seconds
                self.broadcast()
                while time.time() < t.ends_at:
                    await asyncio.sleep(0.1)
                t.close_match(set(self.player_ids()))
                t.stage = "result"
                t.ends_at = None
                self.broadcast()
                await asyncio.sleep(RESULT_SECONDS)
            t.stage = "champion"
            self.broadcast()
            await asyncio.sleep(CHAMPION_SECONDS)
        except asyncio.CancelledError:
            return
        self._tournament_task = None
        champion = t.champion
        self.tournament = None
        # launch() needs to start from the library phase on failure too.
        self._set_phase(SessionPhase.LIBRARY)
        await self.launch(champion)
        if self.phase == SessionPhase.LIBRARY:
            self.broadcast()

    def set_match_seconds(self, seconds: float):
        self.match_seconds = max(3.0, min(60.0, float(seconds)))

    # ----------------------------------------------------------- countdown

    def start_countdown(self, game_id: str, broadcast: bool = True):
        if self.phase != SessionPhase.LIBRARY or self.library.get(game_id) is None:
            return False
        self.cancel_countdown(broadcast=False)
        self.countdown_game_id = game_id
        self.countdown_ends_at = time.time() + COUNTDOWN_SECONDS
        self._countdown_task = asyncio.get_running_loop().create_task(self._run_countdown(game_id))
        if broadcast:
            self.broadcast()
        return True

    def cancel_countdown(self, broadcast: bool = True):
        if self._countdown_task is not None:
            self._countdown_task.cancel()
        self._countdown_task = None
        had = self.countdown_game_id is not None
        self.countdown_game_id = None
        self.countdown_ends_at = None
        if had and broadcast:
            self.broadcast()

    async def _run_countdown(self, game_id: str):
        try:
            await asyncio.sleep(COUNTDOWN_SECONDS)
        except asyncio.CancelledError:
            return
        self._countdown_task = None
        self.countdown_game_id = None
        self.countdown_ends_at = None
        await self.launch(game_id)

    # -------------------------------------------------------------- launch

    async def launch(self, game_id: str):
        game = self.library.get(game_id)
        if game is None:
            return
        self.last_error = None
        try:
            settings = resolve_settings(game, len(self.player_ids()))
            mode = settings["controllerMode"]
            if mode and mode != getattr(self.manager.config, "controller_type", None):
                await self.manager.update_server_settings(mode=mode)
                self.admin_panel.broadcast_update()
            preset_id = settings["presetId"]
            if preset_id and preset_id in self.manager.preset_store.all_presets_by_id:
                self.manager.preset_store.set_active_preset(preset_id)
                self.manager.broadcast_active_layout()
            running = await asyncio.to_thread(start_game, game)
        except LaunchError as e:
            self.last_error = str(e)
            LOGGER.error("Could not launch %s: %s", game["name"], e)
            self.broadcast()
            return

        self.running = running
        self.votes.clear()
        self._set_phase(SessionPhase.IN_GAME)
        if running.tracked:
            loop = asyncio.get_running_loop()
            self._watch_task = loop.create_task(watch_game(running, self._on_game_exit))
            self._placement_task = loop.create_task(
                enforce_placement(running, game.get("display"), game.get("fullscreen", True))
            )
            self.game_in_front = True
            self._guard_task = loop.create_task(self._guard_foreground())
        self.broadcast()

    def _on_game_exit(self, handoff: bool):
        if handoff:
            # The launcher handed off to another process; the game is likely
            # still running, so stay in game until the host returns.
            self.broadcast()
            return
        self.return_from_game()

    def stop_game(self):
        if self.running is not None:
            self.running.kill()
        self.return_from_game()

    def return_from_game(self):
        for task in (self._watch_task, self._placement_task, self._guard_task):
            if task is not None:
                task.cancel()
        self._watch_task = None
        self._placement_task = None
        self._guard_task = None
        self.game_in_front = True
        self.overlay_owner = None
        self.running = None
        self.overlay_open = False
        self.overlay_shot = None
        self.ready.clear()
        self.votes.clear()
        self._set_phase(SessionPhase.LOBBY)
        self.broadcast()

    # ------------------------------------------------------------- payload

    def to_payload(self) -> dict:
        players = []
        for slot in self.manager.slots:
            device_id = slot.assigned_device_id
            if not device_id or not slot.connected:
                continue
            players.append({
                "deviceId": device_id,
                "slot": slot.slot_id,
                "ready": device_id in self.ready,
                "vote": self.votes.get(device_id),
            })
        return {
            "type": "session_update",
            "phase": self.phase.value,
            "inputMode": self.input_mode.value,
            "focused": self.focused,
            "players": players,
            "allReady": self.all_ready(),
            "countdown": {
                "gameId": self.countdown_game_id,
                "endsAt": self.countdown_ends_at,
                "seconds": COUNTDOWN_SECONDS,
            } if self.countdown_game_id else None,
            "runningGame": self.running.to_payload() if self.running else None,
            "lastError": self.last_error,
            "tournament": self.tournament.to_payload() if self.tournament else None,
            "matchSeconds": self.match_seconds,
            "overlayOpen": self.overlay_open,
            "overlayOwner": self.overlay_owner,
            "overlayShotId": self.overlay_shot_id if self.overlay_shot else None,
            "gameInFront": self.game_in_front,
        }

    def phone_payload(self, device_id: str | None = None) -> dict:
        """What one phone needs: whether a game runs (the face button becomes
        Home), whether its input drives MaNet menus (it then shows the menu
        controls: Select / Back / Avatar), and whether someone else holds
        the overlay."""
        overlay_mine = self.overlay_open and self.overlay_owner in (None, device_id)
        # While the overlay is open everyone is in menu mode: the owner drives
        # the menu, the others play with their faces in the playground.
        menu = self.input_mode == InputMode.MENU
        owner_name = None
        if self.overlay_open and not overlay_mine and self.overlay_owner:
            owner_name = self.manager.connected_devices.get(self.overlay_owner, {}).get("name")
        return {
            "type": "session_phase",
            "phase": self.phase.value,
            "overlayOpen": self.overlay_open,
            "overlayMine": overlay_mine,
            "overlayOwnerName": owner_name,
            "menu": menu,
            "paused": self.input_mode == InputMode.PAUSED,
            "me": device_id,
            "mySlot": self.manager.device_map.get(device_id) if device_id else None,
            "seats": self.seats_payload(),
        }

    # --------------------------------------------------------------- seats

    def _identity(self, device_id: str) -> dict:
        identity = self.manager.get_device_identity(device_id)
        name = self.manager.connected_devices.get(device_id, {}).get("name")
        slot = self.manager.get_slot_by_device(device_id)
        if slot is not None and slot.player_name:
            name = slot.player_name
        return {
            "deviceId": device_id,
            "name": name or "",
            "color": identity.get("color"),
            "faceText": identity.get("faceText"),
            "faceRotation": identity.get("faceRotation"),
        }

    def seats_payload(self) -> dict:
        """Who sits where: what phones show to pick a swap or the bench."""
        slots = []
        for slot in self.manager.slots:
            occupant = None
            if slot.assigned_device_id:
                occupant = {**self._identity(slot.assigned_device_id), "connected": slot.connected}
            slots.append({"slot": slot.slot_id, "player": occupant})
        bench = [
            self._identity(device_id)
            for device_id in self.manager.connected_devices
            if device_id not in self.manager.device_map
        ]
        return {"slots": slots, "bench": bench}

    def go_to_bench(self, device_id: str) -> bool:
        slot = self.manager.get_slot_by_device(device_id)
        if slot is None:
            return False
        LOGGER.info("Device %s moves to the bench", device_id)
        reset_slot_gamepad(slot)
        self.manager.unassign_slot(slot.slot_id)
        self.admin_panel.broadcast_update()
        return True

    def join_from_bench(self, device_id: str) -> bool:
        if device_id in self.manager.device_map:
            return False
        name = self.manager.connected_devices.get(device_id, {}).get("name")
        slot = self.manager.assign_slot(device_id, name)
        if slot is None:
            return False
        slot.connected = True
        self.manager.notify_device(device_id, {
            "type": "assigned",
            "slot": slot.slot_id,
            "name": slot.player_name,
            **self.manager.get_slot_identity(slot),
            "total_slots": len(self.manager.slots),
        })
        self.admin_panel.broadcast_update()
        return True

    def request_swap(self, from_id: str, target_id: str) -> bool:
        """Ask `target_id` to trade places with `from_id`; they must accept."""
        if from_id == target_id or target_id not in self.manager.device_ws_map:
            return False
        from_slot = self.manager.device_map.get(from_id)
        target_slot = self.manager.device_map.get(target_id)
        if from_slot is None and target_slot is None:
            return False
        self._swap_offers[target_id] = (from_id, time.time() + SWAP_OFFER_SECONDS)
        self.manager.pulse_device(target_id)
        self.manager.notify_device(target_id, {
            "type": "swap_offer",
            "from": self._identity(from_id),
            "fromSlot": from_slot,
            "toSlot": target_slot,
            "expiresIn": SWAP_OFFER_SECONDS,
        })
        return True

    def answer_swap(self, target_id: str, from_id: str, accept: bool) -> bool:
        offer = self._swap_offers.pop(target_id, None)
        if offer is None or offer[0] != from_id or time.time() > offer[1]:
            return False
        if accept:
            self._swap_places(from_id, target_id)
        self.manager.notify_device(from_id, {
            "type": "swap_result",
            "accepted": accept,
            "by": self._identity(target_id),
        })
        return True

    def _swap_places(self, a: str, b: str):
        slot_a = self.manager.device_map.get(a)
        slot_b = self.manager.device_map.get(b)
        LOGGER.info("Swapping places: %s (slot %s) <-> %s (slot %s)", a, slot_a, b, slot_b)
        if slot_a is not None and slot_b is not None:
            self.manager.swap_slots(slot_a, slot_b)
        elif slot_b is not None:  # a was on the bench: takes b's place
            self.manager.unassign_slot(slot_b)
            self.manager.assign_to_slot(a, slot_b)
        elif slot_a is not None:
            self.manager.unassign_slot(slot_a)
            self.manager.assign_to_slot(b, slot_a)
        for index in (slot_a, slot_b):
            if index is not None and index < len(self.manager.slots):
                reset_slot_gamepad(self.manager.slots[index])
        self.admin_panel.broadcast_update()

    def broadcast(self):
        self.admin_panel.broadcast_event(self.to_payload())
        for device_id in list(self.manager.device_ws_map.keys()):
            phone = self.phone_payload(device_id)
            if phone != self._last_phone_payloads.get(device_id):
                self._last_phone_payloads[device_id] = phone
                self.manager.notify_device(device_id, phone)
