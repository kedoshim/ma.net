"""
Session state: the server-side source of truth for what the whole couch is
doing. Desktop and phones render it and send intents; they never own it.

    lobby ──(everyone ready + 5s)──> library ──(votes + countdown)──> in_game
      ^                                  │                                │
      └──(majority agrees / host)────────┘<──────(game exits / host)──────┘
      └───────────────(free mode: MaNet steps aside)──────────────> in_game

Input routing follows the screen: in the lobby (QR code) and the game
selection, phone input always drives MaNet (ready toggles, cursors, votes)
and never reaches the virtual gamepads. In a game, or in free mode (MaNet
minimized, any game opened by hand), input goes to the gamepads.
"""
import asyncio
import logging
import os
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
    find_main_window,
    focus_window,
    foreground_window,
    is_window,
    list_displays,
    move_to_monitor,
    window_monitor,
)

LOGGER = logging.getLogger(__name__)

COUNTDOWN_SECONDS = 3.0
# Everyone ready in the lobby: the game selection opens after this.
LOBBY_COUNTDOWN_SECONDS = 5.0
# How long a "back to the lobby?" request waits for the majority.
LOBBY_REQUEST_SECONDS = 20.0


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
        # The lobby (QR code screen) owns the phones from the start.
        self.input_mode = InputMode.MENU
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
        # The window the players are playing in, so the overlay opens on its
        # monitor and "back to the game" can focus it again (also works for
        # games started through a launcher, which we can't track by pid).
        self.game_hwnd: int | None = None
        self._guard_task: asyncio.Task | None = None
        self._last_phone_payloads: dict[str, dict] = {}
        # target deviceId -> (requesting deviceId, expiry timestamp)
        self._swap_offers: dict[str, tuple[str, float]] = {}
        self.tournament: Tournament | None = None
        self._tournament_task: asyncio.Task | None = None
        self.match_seconds = MATCH_SECONDS_DEFAULT
        # Free mode: MaNet steps aside and phones are plain gamepads for any
        # game opened by hand. The host can turn the option off.
        self.free_mode = False
        self.free_mode_enabled = True
        self.lobby_countdown_ends_at: float | None = None
        self._lobby_countdown_task: asyncio.Task | None = None
        # Someone asked to leave the game selection: {"from", "yes", "no", "endsAt"}.
        self.lobby_request: dict | None = None
        self._lobby_request_task: asyncio.Task | None = None
        # deviceId -> gameId whose details that phone is reading.
        self.reading: dict[str, str] = {}

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
        for device_id in list(self.reading):
            if device_id not in players:
                del self.reading[device_id]
        self._sync_lobby_request(players)
        self._check_lobby_countdown()
        # Always publish: a player joining changes "everyone ready" too.
        self.broadcast()

    # ------------------------------------------------------------ input mode

    def routes_to_game(self) -> bool:
        return self.input_mode == InputMode.GAME

    def _refresh_input_mode(self):
        # The screen decides, not window focus: the lobby and the game
        # selection always own the phones.
        menu = self.overlay_open or self.phase in MENU_PHASES
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
        # A ready / select, B not ready / cancel my selection, X info and
        # Y emote (desktop only); START/SELECT keep working on real pads.
        if self.phase == SessionPhase.LOBBY:
            if button in ("A", "START") and device_id not in self.ready:
                self.ready.add(device_id)
                self.manager.pulse_device(device_id)
                self._check_lobby_countdown()
                self.broadcast()
            elif button == "B" and device_id in self.ready:
                self.ready.discard(device_id)
                self._check_lobby_countdown()
                self.broadcast()
        elif self.phase == SessionPhase.LIBRARY:
            # A, B and X are resolved by the desktop, which knows what each
            # cursor is over.
            if button == "SELECT":
                self.request_lobby(device_id)
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
            await asyncio.to_thread(self._remember_game_window, True)
            self.overlay_monitor = await asyncio.to_thread(self._game_monitor)
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

    def _own_pids(self) -> set[int]:
        desktop_pid = getattr(self.manager.config, "parent_pid", None)
        return {os.getpid(), *([desktop_pid] if desktop_pid else [])}

    def _remember_game_window(self, at_home: bool = False):
        """Update `game_hwnd` (runs in a worker thread).

        Order: the window in front when it belongs to the game; for a game
        we can't track (launcher), whatever was in front when Home was
        pressed unless it is MaNet itself; then the tracked processes' main
        window (also when minimized); else keep the one remembered."""
        hwnd, pid = foreground_window()
        pids = self._game_pids()
        if hwnd and pid and pid in pids:
            self.game_hwnd = hwnd
            return
        if at_home and hwnd and pid and not pids and pid not in self._own_pids():
            self.game_hwnd = hwnd
            return
        if pids:
            main = find_main_window(pids)
            if main:
                self.game_hwnd = main
                return
        if not is_window(self.game_hwnd):
            self.game_hwnd = None

    def _game_monitor(self) -> dict | None:
        """The game's monitor; else the one chosen for the game; else None
        (never "whatever window happens to be in front")."""
        monitor = window_monitor(self.game_hwnd)
        if monitor:
            return monitor
        index = (self.running.game.get("display") if self.running else None)
        if index is not None:
            return next((d for d in list_displays() if d["index"] == index), None)
        return None

    def focus_game(self) -> bool:
        """Bring the game window back to the front (server-side fallback;
        the desktop normally does it itself while it still has the focus)."""
        self._remember_game_window()
        return focus_window(self.game_hwnd)

    def game_window(self) -> int | None:
        self._remember_game_window()
        return self.game_hwnd

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
                hwnd, pid = await asyncio.to_thread(foreground_window)
                pids = await asyncio.to_thread(self._game_pids)
                in_front = pid is None or pid in pids
                if hwnd and pid in pids:
                    self.game_hwnd = hwnd
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
        self._clear_lobby_request()
        self._cancel_lobby_countdown()
        self.reading.clear()
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

    # ------------------------------------------------------- lobby countdown

    def _check_lobby_countdown(self):
        """Everyone ready starts the countdown to the game selection; anyone
        un-readying (or someone new arriving) stops it."""
        should_run = self.phase == SessionPhase.LOBBY and self.all_ready()
        if should_run and self._lobby_countdown_task is None:
            self.lobby_countdown_ends_at = time.time() + LOBBY_COUNTDOWN_SECONDS
            self._lobby_countdown_task = asyncio.get_running_loop().create_task(
                self._run_lobby_countdown()
            )
        elif not should_run:
            self._cancel_lobby_countdown()

    def _cancel_lobby_countdown(self):
        if self._lobby_countdown_task is not None:
            self._lobby_countdown_task.cancel()
        self._lobby_countdown_task = None
        self.lobby_countdown_ends_at = None

    async def _run_lobby_countdown(self):
        try:
            await asyncio.sleep(LOBBY_COUNTDOWN_SECONDS)
        except asyncio.CancelledError:
            return
        self._lobby_countdown_task = None
        self.lobby_countdown_ends_at = None
        self.enter_library()

    # ------------------------------------------------- back-to-lobby request

    @staticmethod
    def _lobby_votes_needed(players: int) -> int:
        return players // 2 + 1

    def request_lobby(self, device_id: str) -> bool:
        """A player wants to leave the game selection: the others are asked
        and the majority (the requester counts) decides."""
        if self.phase != SessionPhase.LIBRARY or device_id not in self.player_ids():
            return False
        if self.lobby_request is not None:
            # Asking while a request is open counts as agreeing with it.
            return self.answer_lobby(device_id, True)
        self.lobby_request = {
            "from": device_id,
            "yes": {device_id},
            "no": set(),
            "endsAt": time.time() + LOBBY_REQUEST_SECONDS,
        }
        LOGGER.info("Device %s asks to go back to the lobby", device_id)
        if self._resolve_lobby_request():
            return True
        for other in self.player_ids():
            if other != device_id:
                self.manager.pulse_device(other)
        self._lobby_request_task = asyncio.get_running_loop().create_task(
            self._expire_lobby_request()
        )
        self.broadcast()
        return True

    def answer_lobby(self, device_id: str, accept: bool) -> bool:
        request = self.lobby_request
        if request is None or device_id not in self.player_ids():
            return False
        request["yes"].discard(device_id)
        request["no"].discard(device_id)
        (request["yes"] if accept else request["no"]).add(device_id)
        if not self._resolve_lobby_request():
            self.broadcast()
        return True

    def _resolve_lobby_request(self) -> bool:
        """Go back when the majority agreed, drop the request when it can't
        reach one any more. True when the request ended."""
        request = self.lobby_request
        if request is None:
            return True
        players = len(self.player_ids())
        needed = self._lobby_votes_needed(players)
        if len(request["yes"]) >= needed:
            self.back_to_lobby()
            return True
        if players - len(request["no"]) < needed:
            self._clear_lobby_request()
            self.broadcast()
            return True
        return False

    async def _expire_lobby_request(self):
        try:
            await asyncio.sleep(LOBBY_REQUEST_SECONDS)
        except asyncio.CancelledError:
            return
        self._lobby_request_task = None
        self.lobby_request = None
        self.broadcast()

    def _clear_lobby_request(self):
        if self._lobby_request_task is not None:
            self._lobby_request_task.cancel()
        self._lobby_request_task = None
        self.lobby_request = None

    def _sync_lobby_request(self, players: set[str]):
        request = self.lobby_request
        if request is None:
            return
        if request["from"] not in players:
            self._clear_lobby_request()
            return
        request["yes"] &= players
        request["no"] &= players
        # Fewer players can mean the majority is already there. Deferred so
        # the phase doesn't change while slots are being updated.
        asyncio.get_running_loop().call_soon(self._resolve_lobby_request)

    def _lobby_request_payload(self, device_id: str | None = None) -> dict | None:
        request = self.lobby_request
        if request is None:
            return None
        answer = None
        if device_id in request["yes"]:
            answer = True
        elif device_id in request["no"]:
            answer = False
        return {
            "from": self._identity(request["from"]),
            "mine": device_id == request["from"],
            "myAnswer": answer,
            "yes": len(request["yes"]),
            "no": len(request["no"]),
            "needed": self._lobby_votes_needed(len(self.player_ids())),
            "endsAt": request["endsAt"],
        }

    # ------------------------------------------------------------ details

    def show_details(self, device_id: str, game_id: str | None) -> bool:
        """The desktop resolved a player's Info press over a game: that phone
        shows the game's details and the player's cursor waits (it doesn't
        scroll the library). None closes them."""
        if device_id not in self.player_ids():
            return False
        if game_id is None:
            if self.reading.pop(device_id, None) is not None:
                self.broadcast()
            return True
        if self.phase != SessionPhase.LIBRARY:
            return False
        game = self.library.get(game_id)
        if game is None:
            return False
        self.reading[device_id] = game_id
        self.manager.notify_device(device_id, {
            "type": "game_details",
            "game": {
                "id": game["id"],
                "name": game["name"],
                "description": game.get("description") or "",
                "tags": game.get("tags") or [],
                "minPlayers": game["minPlayers"],
                "maxPlayers": game["maxPlayers"],
                "trailerUrl": game.get("trailerUrl") or "",
                "screenshots": game.get("screenshots") or [],
                "coverUrl": f"/api/games/{game['id']}/cover" if game.get("coverPath") else None,
            },
        })
        self.broadcast()
        return True

    # ---------------------------------------------------------- free mode

    def enter_free_mode(self) -> bool:
        """MaNet steps aside: phones become plain gamepads for whatever the
        host opens by hand. Home on a phone brings the overlay back."""
        if not self.free_mode_enabled or self.phase not in (SessionPhase.LOBBY, SessionPhase.LIBRARY):
            return False
        LOGGER.info("Entering free mode")
        self.cancel_countdown(broadcast=False)
        self.votes.clear()
        self.ready.clear()
        self.last_error = None
        self.free_mode = True
        self.running = None
        self.game_in_front = True
        self._set_phase(SessionPhase.IN_GAME)
        self.broadcast()
        return True

    def set_free_mode_enabled(self, enabled: bool):
        self.free_mode_enabled = bool(enabled)

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

        self.library.touch(game_id)
        self.admin_panel.broadcast_event({"type": "games_update", "games": self.library.list()})
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
            self.game_hwnd = None
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
        self.game_hwnd = None
        self.overlay_owner = None
        self.running = None
        self.overlay_open = False
        self.overlay_shot = None
        self.free_mode = False
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
            "freeMode": self.free_mode,
            "freeModeEnabled": self.free_mode_enabled,
            "lobbyCountdown": {
                "endsAt": self.lobby_countdown_ends_at,
                "seconds": LOBBY_COUNTDOWN_SECONDS,
            } if self.lobby_countdown_ends_at else None,
            "lobbyRequest": self._lobby_request_payload(),
            "reading": dict(self.reading),
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
            "ready": device_id in self.ready,
            "myVote": self.votes.get(device_id),
            "reading": self.reading.get(device_id),
            "freeMode": self.free_mode,
            "lobbyCountdownEndsAt": self.lobby_countdown_ends_at,
            "lobbyRequest": self._lobby_request_payload(device_id),
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
