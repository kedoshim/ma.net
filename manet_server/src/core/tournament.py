"""
Elimination tournament between the games the players picked in the library.

The bracket is built once from the library votes; each match is a timed
head-to-head where every player leans to one side. Pure state + rules here;
the session drives the timing (see SessionState._run_tournament).

Rules
- Candidates: each voted game once. Byes (to fill a power-of-two bracket)
  go to the most voted games; ties are drawn.
- One vote per player per match, changeable until the match closes;
  players may abstain. Votes of players who leave are dropped.
- A match closes when its timer ends; once every player has voted the
  remaining time is cut to a short grace period.
- Tie or no votes: one of the two is drawn at random.
"""
import random

MATCH_SECONDS_DEFAULT = 10.0
ALL_VOTED_GRACE_SECONDS = 2.0
INTRO_SECONDS = 3.0
RESULT_SECONDS = 2.5
CHAMPION_SECONDS = 3.5


def _next_power_of_two(n: int) -> int:
    size = 1
    while size < n:
        size *= 2
    return size


class Tournament:
    def __init__(self, vote_counts: dict[str, int], rng: random.Random | None = None):
        self.rng = rng or random.Random()
        self.champion: str | None = None
        self.rounds: list[list[dict]] = []
        self._build(vote_counts)
        self.round_index = 0
        self.match_index = -1
        self.stage = "intro"  # intro | match | result | champion
        self.votes: dict[str, str] = {}  # deviceId -> "a" | "b"
        self.ends_at: float | None = None
        self.last_result: dict | None = None

    # ------------------------------------------------------------ bracket

    def _build(self, vote_counts: dict[str, int]):
        games = list(vote_counts)
        self.rng.shuffle(games)  # random order among equal vote counts
        games.sort(key=lambda g: vote_counts[g], reverse=True)
        size = _next_power_of_two(len(games))
        byes = size - len(games)
        seeded, rest = games[:byes], games[byes:]
        self.rng.shuffle(rest)
        first = [{"a": g, "b": None, "winner": g} for g in seeded]
        first += [{"a": rest[i], "b": rest[i + 1], "winner": None} for i in range(0, len(rest), 2)]
        self.rng.shuffle(first)
        self.rounds = [first]
        while len(self.rounds[-1]) > 1:
            self.rounds.append(
                [{"a": None, "b": None, "winner": None} for _ in range(len(self.rounds[-1]) // 2)]
            )
        # Byes advance right away.
        for index, match in enumerate(first):
            if match["winner"]:
                self._advance(0, index, match["winner"])

    def _advance(self, round_index: int, match_index: int, game_id: str):
        if round_index + 1 >= len(self.rounds):
            self.champion = game_id
            return
        target = self.rounds[round_index + 1][match_index // 2]
        target["a" if match_index % 2 == 0 else "b"] = game_id

    # ------------------------------------------------------------ matches

    def current(self) -> dict | None:
        if self.match_index < 0:
            return None
        return self.rounds[self.round_index][self.match_index]

    def next_match(self) -> dict | None:
        """Move to the next match that needs a vote (both sides known)."""
        for r, matches in enumerate(self.rounds):
            for m, match in enumerate(matches):
                if match["winner"] is None and match["a"] and match["b"]:
                    self.round_index, self.match_index = r, m
                    self.votes = {}
                    return match
        return None

    def vote(self, device_id: str, side: str | None) -> bool:
        if self.stage != "match" or side not in ("a", "b", None):
            return False
        if side is None:
            return self.votes.pop(device_id, None) is not None
        if self.votes.get(device_id) == side:
            return False
        self.votes[device_id] = side
        return True

    def drop_voters(self, keep: set[str]):
        self.votes = {d: s for d, s in self.votes.items() if d in keep}

    def close_match(self, players: set[str]) -> dict:
        """Decide the current match; returns {winner, loser, a, b, drawn}."""
        match = self.current()
        counted = [side for device, side in self.votes.items() if device in players]
        a_votes, b_votes = counted.count("a"), counted.count("b")
        drawn = a_votes == b_votes
        if drawn:
            side = self.rng.choice(("a", "b"))
        else:
            side = "a" if a_votes > b_votes else "b"
        winner = match[side]
        loser = match["b" if side == "a" else "a"]
        match["winner"] = winner
        match["votesA"], match["votesB"] = a_votes, b_votes
        self._advance(self.round_index, self.match_index, winner)
        self.last_result = {"winner": winner, "loser": loser, "side": side, "drawn": drawn}
        return self.last_result

    def to_payload(self) -> dict:
        return {
            "stage": self.stage,
            "rounds": self.rounds,
            "round": self.round_index,
            "match": self.match_index,
            "votes": self.votes,
            "endsAt": self.ends_at,
            "result": self.last_result,
            "champion": self.champion,
        }
