"""
Games the couch can pick from. Registered manually by the host (path to the
executable or shortcut, cover image, player range, controller layout).
"""
import json
import time
import logging
import os
import uuid
from pathlib import Path

from src.app.config import user_data_dir

LOGGER = logging.getLogger(__name__)

MAX_PLAYERS_LIMIT = 16
# A game closed sooner than this was opened by mistake or didn't work: it
# goes in the history but doesn't count as played.
MIN_PLAY_SECONDS = 120
# A play counts half as much after this long: a favorite the couch dropped
# slowly leaves the top of the library.
SCORE_HALF_LIFE_DAYS = 60


class GameValidationError(ValueError):
    pass


def _default_storage_path() -> Path:
    override = os.environ.get("MANET_GAMES_FILE")
    if override:
        return Path(override)
    return user_data_dir() / "games.json"


def normalize_game(data: dict, game_id: str | None = None) -> dict:
    if not isinstance(data, dict):
        raise GameValidationError("invalid_body")

    name = str(data.get("name") or "").strip()
    if not name:
        raise GameValidationError("missing_name")
    path = str(data.get("path") or "").strip()
    if not path:
        raise GameValidationError("missing_path")

    try:
        min_players = int(data.get("minPlayers") or 1)
        max_players = int(data.get("maxPlayers") or min_players)
    except (TypeError, ValueError):
        raise GameValidationError("invalid_players")
    min_players = max(1, min(min_players, MAX_PLAYERS_LIMIT))
    max_players = max(min_players, min(max_players, MAX_PLAYERS_LIMIT))

    controller_mode = data.get("controllerMode")
    if controller_mode not in ("x360", "ds4"):
        controller_mode = None

    rules = []
    for rule in data.get("rules") or []:
        if not isinstance(rule, dict):
            continue
        try:
            low = max(1, min(int(rule.get("minPlayers") or 1), MAX_PLAYERS_LIMIT))
            high = max(low, min(int(rule.get("maxPlayers") or low), MAX_PLAYERS_LIMIT))
        except (TypeError, ValueError):
            continue
        mode = rule.get("controllerMode")
        rules.append({
            "minPlayers": low,
            "maxPlayers": high,
            "controllerMode": mode if mode in ("x360", "ds4") else None,
            "presetId": rule.get("presetId") or None,
        })

    tags = []
    raw_tags = data.get("tags") or []
    if isinstance(raw_tags, str):
        raw_tags = raw_tags.split(",")
    for tag in raw_tags:
        tag = str(tag).strip()[:24]
        if tag and tag.lower() not in (t.lower() for t in tags):
            tags.append(tag)
    try:
        added_at = float(data.get("addedAt") or 0) or time.time()
    except (TypeError, ValueError):
        added_at = time.time()

    try:
        last_played_at = max(0.0, float(data.get("lastPlayedAt") or 0))
    except (TypeError, ValueError):
        last_played_at = 0.0

    try:
        plays = max(0, int(data.get("plays") or 0))
        play_seconds = max(0.0, float(data.get("playSeconds") or 0))
    except (TypeError, ValueError):
        plays, play_seconds = 0, 0.0

    screenshots = []
    for url in data.get("screenshots") or []:
        url = str(url).strip()
        if url.startswith(("http://", "https://")) and url not in screenshots:
            screenshots.append(url)

    display = data.get("display")
    display = int(display) if isinstance(display, (int, float)) and display >= 0 else None

    return {
        "id": game_id or data.get("id") or uuid.uuid4().hex[:12],
        "name": name[:60],
        "path": path,
        "arguments": str(data.get("arguments") or "").strip(),
        "workingDirectory": str(data.get("workingDirectory") or "").strip(),
        "coverPath": str(data.get("coverPath") or "").strip(),
        "minPlayers": min_players,
        "maxPlayers": max_players,
        "presetId": data.get("presetId") or None,
        "controllerMode": controller_mode,
        # Per player-count overrides, first match wins (e.g. 1-4 x•input,
        # 5-8 d•input). Unset fields fall back to the defaults above.
        "rules": rules,
        # Monitor index (see /api/displays); None keeps the game's choice.
        "display": display,
        # Make windowed games cover their monitor (borderless).
        "fullscreen": bool(data.get("fullscreen", True)),
        # Shown in the library: short text, genre/category tags, a trailer
        # link (YouTube/Steam/any URL) and when it was added (for sorting).
        "description": str(data.get("description") or "").strip()[:1200],
        "tags": tags[:12],
        "trailerUrl": str(data.get("trailerUrl") or "").strip(),
        "addedAt": added_at,
        # When MaNet last launched it: the library starts centered on the
        # most recently played games.
        "lastPlayedAt": last_played_at,
        # How often and how long it was really played (see record_play): the
        # couch's favorites, for ordering the library.
        "plays": plays,
        "playSeconds": play_seconds,
        # Image URLs shown on a player's phone with the game details.
        "screenshots": screenshots[:8],
        # Games played in the phone's browser (Jackbox): while the game runs
        # the pad shows a button that opens this page. Empty: no button.
        # Set by the host in the game editor (jackbox.tv is suggested there).
        "phoneUrl": _web_url(data.get("phoneUrl")),
    }


def _web_url(value) -> str:
    url = str(value or "").strip()
    return url if url.startswith(("http://", "https://")) else ""


def phone_game_url(game: dict | None) -> str | None:
    """The page players open on their phones for this game, if the host
    turned the site button on for it."""
    return (game or {}).get("phoneUrl") or None


def resolve_settings(game: dict, players: int) -> dict:
    """Controller mode and layout to use for `players` players."""
    settings = {"controllerMode": game.get("controllerMode"), "presetId": game.get("presetId")}
    for rule in game.get("rules") or []:
        if rule["minPlayers"] <= players <= rule["maxPlayers"]:
            for key in ("controllerMode", "presetId"):
                if rule.get(key):
                    settings[key] = rule[key]
            break
    return settings


class GameLibraryStore:
    def __init__(self, storage_path: Path | None = None):
        self.storage_path = Path(storage_path) if storage_path else _default_storage_path()
        self._games: list[dict] = self._load()
        # (game id, start time) of every play that counted, for the scores.
        self._plays: list[tuple[str, float]] = self._load_plays()

    def _load(self) -> list[dict]:
        try:
            if self.storage_path.exists():
                raw = json.loads(self.storage_path.read_text(encoding="utf-8"))
                games = []
                for index, item in enumerate(raw.get("games", [])):
                    # Games saved before addedAt existed keep their order,
                    # older than anything added from now on.
                    if isinstance(item, dict) and not item.get("addedAt"):
                        item["addedAt"] = 1 + index
                    try:
                        games.append(normalize_game(item, item.get("id")))
                    except GameValidationError:
                        LOGGER.warning("Skipping invalid game entry: %s", item)
                return games
        except Exception:
            LOGGER.exception("Failed to load game library from %s", self.storage_path)
        return []

    def _save(self):
        self.storage_path.parent.mkdir(parents=True, exist_ok=True)
        tmp = self.storage_path.with_suffix(".tmp")
        tmp.write_text(json.dumps({"games": self._games}, ensure_ascii=False, indent=2), encoding="utf-8")
        tmp.replace(self.storage_path)

    def _load_plays(self) -> list[tuple[str, float]]:
        plays = []
        try:
            if self.history_path.exists():
                for line in self.history_path.read_text(encoding="utf-8").splitlines():
                    try:
                        entry = json.loads(line)
                        if float(entry.get("seconds") or 0) >= MIN_PLAY_SECONDS:
                            plays.append((str(entry["gameId"]), float(entry["startedAt"])))
                    except (ValueError, KeyError, TypeError):
                        continue
        except Exception:
            LOGGER.exception("Failed to read the play history")
        return plays

    def scores(self, now: float | None = None) -> dict[str, float]:
        """How much the couch likes each game lately: every play is worth 1,
        halving every SCORE_HALF_LIFE_DAYS."""
        now = time.time() if now is None else now
        half_life = SCORE_HALF_LIFE_DAYS * 86400
        scores: dict[str, float] = {}
        for game_id, started_at in self._plays:
            age = max(0.0, now - started_at)
            scores[game_id] = scores.get(game_id, 0.0) + 0.5 ** (age / half_life)
        return scores

    def list(self) -> list[dict]:
        scores = self.scores()
        return [{**game, "score": round(scores.get(game["id"], 0.0), 3)} for game in self._games]

    def get(self, game_id: str) -> dict | None:
        return next((dict(g) for g in self._games if g["id"] == game_id), None)

    def add(self, data: dict) -> dict:
        game = normalize_game(data)
        self._games.append(game)
        self._save()
        return dict(game)

    def update(self, game_id: str, data: dict) -> dict | None:
        for index, existing in enumerate(self._games):
            if existing["id"] == game_id:
                if isinstance(data, dict):
                    for key in ("addedAt", "lastPlayedAt", "plays", "playSeconds"):
                        if not data.get(key):
                            data = {**data, key: existing.get(key)}
                game = normalize_game(data, game_id)
                self._games[index] = game
                self._save()
                return dict(game)
        return None

    @property
    def history_path(self) -> Path:
        return self.storage_path.with_name("play_history.jsonl")

    def record_play(self, game_id: str, started_at: float, seconds: float, players: int):
        """Notes a finished session: one line per play in the history (kept
        for later questions) and the totals on the game."""
        game = next((g for g in self._games if g["id"] == game_id), None)
        if game is None:
            return
        seconds = max(0.0, round(seconds, 1))
        entry = {"gameId": game_id, "name": game["name"], "startedAt": round(started_at, 1),
                 "seconds": seconds, "players": players}
        try:
            self.history_path.parent.mkdir(parents=True, exist_ok=True)
            with self.history_path.open("a", encoding="utf-8") as f:
                f.write(json.dumps(entry, ensure_ascii=False) + "\n")
        except Exception:
            LOGGER.exception("Failed to write the play history")
        if seconds < MIN_PLAY_SECONDS:
            return
        self._plays.append((game_id, started_at))
        game["plays"] = game.get("plays", 0) + 1
        game["playSeconds"] = game.get("playSeconds", 0.0) + seconds
        try:
            self._save()
        except Exception:
            LOGGER.exception("Failed to save the game library")

    def touch(self, game_id: str):
        """Remember that the game was just played."""
        for game in self._games:
            if game["id"] == game_id:
                game["lastPlayedAt"] = time.time()
                try:
                    self._save()
                except Exception:
                    LOGGER.exception("Failed to save the game library")
                return

    def delete(self, game_id: str) -> bool:
        before = len(self._games)
        self._games = [g for g in self._games if g["id"] != game_id]
        if len(self._games) != before:
            self._save()
            return True
        return False
