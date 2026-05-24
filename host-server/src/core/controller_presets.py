import json
from copy import deepcopy
from pathlib import Path


BUTTON_ORDER = [
    "btnY",
    "btnB",
    "btnX",
    "btnA",
    "btnRB",
    "btnRT",
    "btnLB",
    "btnLT",
    "btnRSB",
    "btnLSB",
]


def _build_visibility(visible_ids):
    return {button_id: button_id in visible_ids for button_id in BUTTON_ORDER}


def _preset(
    preset_id,
    *,
    name,
    category,
    movement_mode,
    visible_ids,
    button_order=None,
):
    return {
        "id": preset_id,
        "name": name,
        "category": category,
        "isBuiltIn": category != "user",
        "layout": {
            "movementMode": movement_mode,
            "visibleButtons": _build_visibility(visible_ids),
            "buttonOrder": list(button_order or BUTTON_ORDER),
        },
    }


BUILT_IN_PRESETS = [
    _preset(
        "builtin-simple-shoulder",
        name="Simple + Shoulder",
        category="builtin",
        movement_mode="floatingJoystick",
        visible_ids=["btnA", "btnB", "btnX", "btnY", "btnLB", "btnRB"],
    ),
    _preset(
        "builtin-simple-trigger",
        name="Simple + Trigger",
        category="builtin",
        movement_mode="floatingJoystick",
        visible_ids=["btnA", "btnB", "btnX", "btnY", "btnLT", "btnRT"],
    ),
    _preset(
        "builtin-full",
        name="Complete",
        category="builtin",
        movement_mode="floatingJoystick",
        visible_ids=[
            "btnA",
            "btnB",
            "btnX",
            "btnY",
            "btnLB",
            "btnRB",
            "btnLT",
            "btnRT",
        ],
    ),
]


GAME_PRESETS = [
    _preset(
        "game-overcooked",
        name="Overcooked",
        category="game",
        movement_mode="floatingJoystick",
        visible_ids=["btnA", "btnB", "btnX", "btnY", "btnLB", "btnRB"],
    ),
    _preset(
        "game-speedrunners",
        name="SpeedRunners",
        category="game",
        movement_mode="dpad",
        visible_ids=["btnA", "btnB", "btnX", "btnY", "btnLB", "btnRB"],
    ),
    _preset(
        "game-pico-park",
        name="Pico Park",
        category="game",
        movement_mode="floatingJoystick",
        visible_ids=["btnA", "btnB", "btnX", "btnY"],
    ),
    _preset(
        "game-party-animals",
        name="Party Animals",
        category="game",
        movement_mode="floatingJoystick",
        visible_ids=["btnA", "btnB", "btnX", "btnY", "btnLB", "btnRB", "btnLT", "btnRT"],
    ),
    _preset(
        "game-boomerang-fu",
        name="Boomerang Fu",
        category="game",
        movement_mode="floatingJoystick",
        visible_ids=["btnA", "btnB", "btnX", "btnY"],
    ),
]


class ControllerPresetStore:
    def __init__(self, storage_path=None):
        root = Path(__file__).resolve().parents[2]
        self.storage_path = Path(storage_path or root / "data" / "controller_presets.json")
        self._builtins = {
            preset["id"]: deepcopy(preset)
            for preset in [*BUILT_IN_PRESETS, *GAME_PRESETS]
        }
        self._custom = {}
        self._active_preset_id = "builtin-simple-shoulder"
        self._load()

    def _load(self):
        if not self.storage_path.exists():
            return

        try:
            payload = json.loads(self.storage_path.read_text(encoding="utf-8"))
        except Exception:
            return

        custom_items = payload.get("customPresets", [])
        active_preset_id = payload.get("activePresetId")

        for item in custom_items:
            normalized = self._normalize_custom_preset(item)
            self._custom[normalized["id"]] = normalized

        if active_preset_id in self.all_presets_by_id:
            self._active_preset_id = active_preset_id

    def _save(self):
        self.storage_path.parent.mkdir(parents=True, exist_ok=True)
        payload = {
            "activePresetId": self._active_preset_id,
            "customPresets": list(self._custom.values()),
        }
        self.storage_path.write_text(
            json.dumps(payload, ensure_ascii=False, indent=2),
            encoding="utf-8",
        )

    @property
    def all_presets_by_id(self):
        return {**self._builtins, **self._custom}

    def _normalize_layout(self, layout):
        base_visibility = _build_visibility([])
        raw_visibility = layout.get("visibleButtons") or {}
        base_visibility.update({
            key: value == True
            for key, value in raw_visibility.items()
            if key in base_visibility
        })

        raw_order = [item for item in (layout.get("buttonOrder") or []) if item in BUTTON_ORDER]
        remaining = [item for item in BUTTON_ORDER if item not in raw_order]

        movement_mode = layout.get("movementMode")
        if movement_mode not in {"dpad", "fixedJoystick", "floatingJoystick"}:
            movement_mode = "floatingJoystick"

        return {
            "movementMode": movement_mode,
            "visibleButtons": base_visibility,
            "buttonOrder": [*raw_order, *remaining],
        }

    def _normalize_custom_preset(self, payload):
        name = (payload.get("name") or "Novo preset").strip() or "Novo preset"
        return {
            "id": payload["id"],
            "name": name,
            "category": "user",
            "isBuiltIn": False,
            "layout": self._normalize_layout(payload.get("layout") or {}),
        }

    def list_payload(self):
        active = self.get_active_preset()
        return {
            "activePresetId": active["id"],
            "activePreset": active,
            "builtInPresets": [
                deepcopy(preset)
                for preset in BUILT_IN_PRESETS
            ],
            "gamePresets": [
                deepcopy(preset)
                for preset in GAME_PRESETS
            ],
            "customPresets": [
                deepcopy(preset)
                for preset in self._custom.values()
            ],
        }

    def get_active_preset(self):
        return deepcopy(self.all_presets_by_id[self._active_preset_id])

    def set_active_preset(self, preset_id):
        if preset_id not in self.all_presets_by_id:
            raise KeyError(preset_id)
        self._active_preset_id = preset_id
        self._save()
        return self.get_active_preset()

    def create_custom_preset(self, payload):
        preset_id = payload.get("id")
        if not preset_id:
            raise ValueError("missing_preset_id")
        normalized = self._normalize_custom_preset(payload)
        self._custom[preset_id] = normalized
        self._save()
        return deepcopy(normalized)

    def update_custom_preset(self, preset_id, payload):
        current = self._custom.get(preset_id)
        if current is None:
            raise KeyError(preset_id)
        merged = deepcopy(current)
        merged.update({k: v for k, v in payload.items() if k != "id"})
        merged["id"] = preset_id
        normalized = self._normalize_custom_preset(merged)
        self._custom[preset_id] = normalized
        self._save()
        return deepcopy(normalized)

    def delete_custom_preset(self, preset_id):
        if preset_id not in self._custom:
            raise KeyError(preset_id)
        del self._custom[preset_id]
        if self._active_preset_id == preset_id:
            self._active_preset_id = "builtin-simple-shoulder"
        self._save()
        return self.get_active_preset()
