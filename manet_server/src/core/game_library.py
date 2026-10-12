"""
Games the couch can pick from. Registered manually by the host (path to the
executable or shortcut, cover image, player range, controller layout).
"""
import json
import logging
import os
import sys
import uuid
from pathlib import Path

LOGGER = logging.getLogger(__name__)

MAX_PLAYERS_LIMIT = 16


class GameValidationError(ValueError):
    pass


def _default_storage_path() -> Path:
    override = os.environ.get("MANET_GAMES_FILE")
    if override:
        return Path(override)
    if getattr(sys, "frozen", False):
        # Installed under Program Files: keep user data in the home folder.
        return Path.home() / ".manet" / "games.json"
    return Path(__file__).resolve().parents[2] / "data" / "games.json"


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
    }


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

    def _load(self) -> list[dict]:
        try:
            if self.storage_path.exists():
                raw = json.loads(self.storage_path.read_text(encoding="utf-8"))
                games = []
                for item in raw.get("games", []):
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

    def list(self) -> list[dict]:
        return [dict(game) for game in self._games]

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
                game = normalize_game(data, game_id)
                self._games[index] = game
                self._save()
                return dict(game)
        return None

    def delete(self, game_id: str) -> bool:
        before = len(self._games)
        self._games = [g for g in self._games if g["id"] != game_id]
        if len(self._games) != before:
            self._save()
            return True
        return False
