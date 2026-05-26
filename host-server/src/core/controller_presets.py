import json
import logging
from copy import deepcopy
from pathlib import Path

LOGGER = logging.getLogger(__name__)


BUTTON_ORDER = [
    "RSB",
    "LSB",
    "LT",
    "RT",
    "LB",
    "RB",
    "Y",
    "B",
    "X",
    "A",
]


LEGACY_BUTTON_IDS = {
    "BTNY": "Y",
    "BTNB": "B",
    "BTNX": "X",
    "BTNA": "A",
    "BTNRB": "RB",
    "BTNRT": "RT",
    "BTNLB": "LB",
    "BTNLT": "LT",
    "BTNRSB": "RSB",
    "BTNLSB": "LSB",
}


def _canonical_button_id(value):
    if value is None:
        return None
    upper = str(value).upper()
    return LEGACY_BUTTON_IDS.get(upper, upper)


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
    raw_order = []
    for item in button_order or []:
        canonical = _canonical_button_id(item)
        if canonical in BUTTON_ORDER and canonical not in raw_order:
            raw_order.append(canonical)
    remaining = [item for item in BUTTON_ORDER if item not in raw_order]
    final_order = [*raw_order, *remaining]

    return {
        "id": preset_id,
        "name": name,
        "category": category,
        "isBuiltIn": category != "user",
        "layout": {
            "movementMode": movement_mode,
            "visibleButtons": _build_visibility(visible_ids),
            "buttonOrder": final_order,
        },
    }


BUILT_IN_PRESETS = [
    _preset(
        "builtin-simple-shoulder",
        name="Simple + Shoulder",
        category="builtin",
        movement_mode="floatingJoystick",
        visible_ids=["A", "B", "X", "Y", "LB", "RB"],
        button_order=["LB", "RB", "Y", "B", "X", "A"],
    ),
    _preset(
        "builtin-simple-trigger",
        name="Simple + Trigger",
        category="builtin",
        movement_mode="floatingJoystick",
        visible_ids=["A", "B", "X", "Y", "LT", "RT"],
        button_order=["LT", "RT", "Y", "B", "X", "A"],
    ),
    _preset(
        "builtin-full",
        name="Complete",
        category="builtin",
        movement_mode="floatingJoystick",
        visible_ids=[
            "A",
            "B",
            "X",
            "Y",
            "LB",
            "RB",
            "LT",
            "RT",
        ],
        button_order=["LT", "RT", "LB", "RB", "Y", "B", "X", "A"],
    ),
]


GAME_PRESETS = [
    _preset(
        "game-overcooked",
        name="Overcooked",
        category="game",
        movement_mode="floatingJoystick",
        visible_ids=["A", "B", "X", "Y",],
        button_order=["Y", "B", "X", "A"],
    ),
    _preset(
        "game-pico-park",
        name="Pico Park",
        category="game",
        movement_mode="dpad",
        visible_ids=["A", "B"],
        button_order=["B", "A"],
    ),
    _preset(
        "game-boomerang-fu",
        name="Boomerang Fu",
        category="game",
        movement_mode="floatingJoystick",
        visible_ids=["A", "B", "X", "Y"],
        button_order=["B", "Y", "X", "A"],
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
            LOGGER.exception("Failed to load controller presets from %s", self.storage_path)
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
        try:
            self.storage_path.write_text(
                json.dumps(payload, ensure_ascii=False, indent=2),
                encoding="utf-8",
            )
        except Exception:
            LOGGER.exception("Failed to save controller presets to %s", self.storage_path)

    @property
    def all_presets_by_id(self):
        return {**self._builtins, **self._custom}

    def _normalize_layout(self, layout):
        base_visibility = _build_visibility([])
        raw_visibility = layout.get("visibleButtons") or {}
        base_visibility.update({
            _canonical_button_id(key): value == True
            for key, value in raw_visibility.items()
            if _canonical_button_id(key) in base_visibility
        })

        raw_order = []
        for item in layout.get("buttonOrder") or []:
            canonical = _canonical_button_id(item)
            if canonical in BUTTON_ORDER and canonical not in raw_order:
                raw_order.append(canonical)
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
        LOGGER.info("Active controller preset set: %s", preset_id)
        return self.get_active_preset()

    def create_custom_preset(self, payload):
        preset_id = payload.get("id")
        if not preset_id:
            raise ValueError("missing_preset_id")
        normalized = self._normalize_custom_preset(payload)
        self._custom[preset_id] = normalized
        self._save()
        LOGGER.info("Created custom controller preset: %s", preset_id)
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
        LOGGER.info("Updated custom controller preset: %s", preset_id)
        return deepcopy(normalized)

    def delete_custom_preset(self, preset_id):
        if preset_id not in self._custom:
            raise KeyError(preset_id)
        del self._custom[preset_id]
        if self._active_preset_id == preset_id:
            self._active_preset_id = "builtin-simple-shoulder"
        self._save()
        LOGGER.info("Deleted custom controller preset: %s", preset_id)
        return self.get_active_preset()
