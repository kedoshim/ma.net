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
from src.services.game_launcher import LaunchError, RunningGame, start_game, watch_game
from src.services.window_placement import enforce_placement

LOGGER = logging.getLogger(__name__)

COUNTDOWN_SECONDS = 3.0


class SessionPhase(str, Enum):
    LOBBY = "lobby"
    LIBRARY = "library"
    IN_GAME = "in_game"


class InputMode(str, Enum):
    # Phone input drives the virtual gamepad (normal play).
    GAME = "game"
    # Phone input drives MaNet menus/cursors and never reaches the game.
    MENU = "menu"


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
        # Always publish: a player joining changes "everyone ready" too.
        self.broadcast()

    # ------------------------------------------------------------ input mode

    def routes_to_game(self) -> bool:
        return self.input_mode == InputMode.GAME

    def _refresh_input_mode(self):
        menu = self.focused and self.phase in (SessionPhase.LOBBY, SessionPhase.LIBRARY)
        mode = InputMode.MENU if menu else InputMode.GAME
        if mode == self.input_mode:
            return
        self.input_mode = mode
        LOGGER.info("Input mode -> %s", mode.value)
        if mode == InputMode.MENU:
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
        if self.phase == SessionPhase.LOBBY:
            if button == "START":
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
            if button == "B":
                self.vote(device_id, None)
            elif button == "SELECT":
                self.back_to_lobby()
            elif button == "START" and self.countdown_game_id is None:
                leader = self.leading_game_id()
                if leader:
                    self.start_countdown(leader)

    def handle_home_pressed(self, device_id: str):
        LOGGER.info("Home pressed by device %s", device_id)
        self.admin_panel.broadcast_event({
            "type": "overlay_toggle",
            "deviceId": device_id,
        })

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
            leader = self.leading_game_id()
            if leader:
                self.start_countdown(leader, broadcast=False)

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
        for task in (self._watch_task, self._placement_task):
            if task is not None:
                task.cancel()
        self._watch_task = None
        self._placement_task = None
        self.running = None
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
        }

    def broadcast(self):
        self.admin_panel.broadcast_event(self.to_payload())
