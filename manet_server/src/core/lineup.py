"""
Lineup: who plays first when a game has fewer seats than players.

    choose ──> (more volunteers than seats?) ──> rounds of a minigame ──> done
                                                 (announce -> pick -> reveal)
                              │ no                                     ^
                              └────────────────────────────────────────┘

1. "choose": everyone walks their face to "play now" or "start on the bench"
   (the desktop reports which side each one stands in).
2. Fewer volunteers than seats: the rest are filled from the bench in queue
   (check-in) order. More volunteers: a quick minigame decides. Each round is
   randomly "dedanha" (everyone shows 0-5 fingers, the sum counts around the
   circle and lands on one person) or "zerinho ou um" (everyone picks 0 or 1,
   the minority group is decided; if it's bigger than needed, it plays again
   among itself).
3. Whoever is decided is out (or in, when choosing the players is shorter
   than choosing who sits out).

Pure state; SessionState drives the timing.
"""
import random

# Choosing a side always lasts the whole time: faces drop in the neutral
# middle and people need a moment to understand and walk.
CHOOSE_SECONDS = 10.0
# Before each round the minigame is announced (no picking yet).
ANNOUNCE_SECONDS = 3.0
PICK_SECONDS = 10.0
REVEAL_SECONDS = 4.5
DONE_SECONDS = 4.0
# Everyone picked/chose already: don't make them wait out the clock.
ALL_PICKED_GRACE_SECONDS = 0.8

DEDANHA = "dedanha"
ZERINHO = "zerinho"
GAMES = (DEDANHA, ZERINHO)
PICK_RANGE = {DEDANHA: range(0, 6), ZERINHO: range(0, 2)}


class Lineup:
    def __init__(self, game_id: str, seats: int, queue: list[str], rng: random.Random | None = None):
        self.game_id = game_id
        self.seats = seats
        # Everyone in the session, in queue (check-in) order.
        self.queue = list(queue)
        self.rng = rng or random.Random()
        self.stage = "choose"
        self.ends_at: float | None = None
        self.zones: dict[str, str | None] = {}
        # Minigame state
        self.mode: str | None = None  # "out": decided players sit out; "in": they play
        self.needed = 0
        self.decided: list[str] = []
        self.candidates: list[str] = []
        self.round_game: str | None = None
        self.picks: dict[str, int] = {}
        self.round_result: dict | None = None
        self.rounds = 0
        self.chosen: list[str] = []
        self.bench: list[str] = []

    # ------------------------------------------------------------ choosing

    def set_zone(self, device_id: str, zone: str | None) -> bool:
        if self.stage != "choose" or device_id not in self.queue:
            return False
        self.zones[device_id] = zone if zone in ("play", "bench") else None
        return True

    def everyone_chose(self) -> bool:
        return all(self.zones.get(d) is not None for d in self.queue)

    def close_choose(self):
        """Volunteers fit: done. Too many: start the minigame."""
        volunteers = [d for d in self.queue if self.zones.get(d) == "play"]
        if len(volunteers) <= self.seats:
            rest = [d for d in self.queue if d not in volunteers]
            self._finish(volunteers + rest[: self.seats - len(volunteers)])
            return
        out = len(volunteers) - self.seats
        # Decide whichever group is smaller: who sits out, or who plays.
        if out <= self.seats:
            self.mode, self.needed = "out", out
        else:
            self.mode, self.needed = "in", self.seats
        self.candidates = volunteers
        self._volunteers = volunteers
        self._start_round()

    # ------------------------------------------------------------- rounds

    def _start_round(self):
        self.stage = "announce"
        self.rounds += 1
        self.round_game = self.rng.choice(GAMES)
        self.picks = {}
        self.round_result = None

    def begin_pick(self):
        self.stage = "pick"

    def pick(self, device_id: str, value: int) -> bool:
        if self.stage != "pick" or device_id not in self.candidates:
            return False
        if value not in PICK_RANGE[self.round_game]:
            return False
        self.picks[device_id] = value
        return True

    def everyone_picked(self) -> bool:
        return all(d in self.picks for d in self.candidates)

    def close_round(self):
        """Fill missing picks at random and resolve the round."""
        for d in self.candidates:
            if d not in self.picks:
                self.picks[d] = self.rng.choice(list(PICK_RANGE[self.round_game]))
        if self.round_game == DEDANHA:
            total = sum(self.picks[d] for d in self.candidates)
            landing = self.candidates[total % len(self.candidates)]
            decided = [landing]
            self.round_result = {"total": total, "landing": landing, "decided": decided}
        else:
            zeros = [d for d in self.candidates if self.picks[d] == 0]
            ones = [d for d in self.candidates if self.picks[d] == 1]
            if not zeros or not ones or len(zeros) == len(ones):
                decided = []  # tie: play again
                minority = []
            else:
                minority = zeros if len(zeros) < len(ones) else ones
                decided = minority if len(minority) <= self.needed else []
            self.round_result = {"minority": minority, "decided": decided, "tie": not minority}
            if minority and not decided:
                # The minority is bigger than needed: it plays again alone.
                self.round_result["narrowTo"] = minority
        self.stage = "reveal"

    def next_round(self) -> bool:
        """After the reveal. True when the lineup is decided."""
        result = self.round_result or {}
        for d in result.get("decided", []):
            self.decided.append(d)
            self.needed -= 1
        remaining = [d for d in self.candidates if d not in self.decided]
        if self.needed <= 0:
            self._resolve()
            return True
        narrow = result.get("narrowTo")
        self.candidates = [d for d in narrow if d not in self.decided] if narrow else remaining
        if len(self.candidates) <= self.needed:
            # Everyone left is decided anyway.
            self.decided += self.candidates
            self.needed = 0
            self._resolve()
            return True
        self._start_round()
        return False

    def _resolve(self):
        volunteers = self._volunteers
        if self.mode == "out":
            playing = [d for d in volunteers if d not in self.decided]
        else:
            playing = [d for d in volunteers if d in self.decided]
        self._finish(playing[: self.seats])

    def _finish(self, chosen: list[str]):
        self.chosen = chosen
        self.bench = [d for d in self.queue if d not in chosen]
        self.stage = "done"

    # ------------------------------------------------------------- players

    def drop(self, present: set[str]):
        """Players who left are no longer part of it."""
        self.queue = [d for d in self.queue if d in present]
        for d in list(self.zones):
            if d not in present:
                del self.zones[d]
        if self.stage in ("announce", "pick"):
            self.candidates = [d for d in self.candidates if d in present]
            self.picks = {d: v for d, v in self.picks.items() if d in present}

    def to_payload(self) -> dict:
        reveal = self.stage in ("reveal", "done")
        return {
            "gameId": self.game_id,
            "seats": self.seats,
            "stage": self.stage,
            "endsAt": self.ends_at,
            "queue": self.queue,
            "zones": self.zones,
            "mode": self.mode,
            "needed": self.needed,
            "decided": self.decided,
            "candidates": self.candidates,
            "round": self.rounds,
            "game": self.round_game,
            "picked": [d for d in self.candidates if d in self.picks],
            "picks": self.picks if reveal else None,
            "result": self.round_result if reveal else None,
            "chosen": self.chosen,
            "bench": self.bench,
        }
