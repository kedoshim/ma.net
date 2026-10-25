"""Every play is noted, so the library can learn what the couch enjoys."""
import json
import time

import pytest

from src.core.game_library import MIN_PLAY_SECONDS, GameLibraryStore
from src.core.session_state import SessionState
from tests.test_tool_mode import _Admin, _Manager


def make_library(tmp_path):
    library = GameLibraryStore(tmp_path / "games.json")
    game = library.add({"name": "Shipped", "path": r"C:\Games\Shipped.exe",
                        "minPlayers": 1, "maxPlayers": 8})
    return library, game["id"]


def history(library):
    return [json.loads(line) for line in library.history_path.read_text(encoding="utf-8").splitlines()]


def test_a_real_play_counts(tmp_path):
    library, game_id = make_library(tmp_path)
    library.record_play(game_id, started_at=1000.0, seconds=600, players=4)
    library.record_play(game_id, started_at=2000.0, seconds=300, players=6)
    game = library.get(game_id)
    assert game["plays"] == 2
    assert game["playSeconds"] == 900
    assert [h["players"] for h in history(library)] == [4, 6]
    # Saved: a new store (the other app, or a restart) sees the same totals.
    assert GameLibraryStore(tmp_path / "games.json").get(game_id)["plays"] == 2


def test_a_quick_open_and_close_is_only_history(tmp_path):
    library, game_id = make_library(tmp_path)
    library.record_play(game_id, started_at=1000.0, seconds=MIN_PLAY_SECONDS - 1, players=2)
    assert library.get(game_id)["plays"] == 0
    assert len(history(library)) == 1


def test_editing_a_game_keeps_its_stats(tmp_path):
    library, game_id = make_library(tmp_path)
    library.record_play(game_id, started_at=1000.0, seconds=600, players=4)
    edited = {**library.get(game_id), "name": "Shipped!"}
    del edited["plays"], edited["playSeconds"]  # the desktop editor doesn't send them
    assert library.update(game_id, edited)["plays"] == 1


def test_returning_from_a_game_records_it(tmp_path):
    library, game_id = make_library(tmp_path)
    state = SessionState(_Manager(console=True), _Admin(), library=library)
    state._play = (game_id, time.time() - 300, 2)
    state.return_from_game()
    assert library.get(game_id)["plays"] == 1
    assert history(library)[0]["players"] == 2
    state.return_from_game()  # only once per game
    assert len(history(library)) == 1


def test_score_counts_recent_plays_more(tmp_path):
    library, game_id = make_library(tmp_path)
    other = library.add({"name": "Nidhogg", "path": r"C:\Games\Nidhogg.exe"})["id"]
    day = 86400
    now = 1_000 * day
    library.record_play(game_id, started_at=now - 60 * day, seconds=600, players=4)
    library.record_play(game_id, started_at=now - 60 * day, seconds=600, players=4)
    library.record_play(other, started_at=now - day, seconds=30, players=2)  # too short
    scores = library.scores(now)
    assert scores[game_id] == pytest.approx(1.0)  # two plays, one half-life ago
    assert other not in scores
    # A restart reads the same scores back from the history.
    assert GameLibraryStore(tmp_path / "games.json").scores(now) == scores
    assert {g["id"]: g["score"] for g in library.list()}[other] == 0
