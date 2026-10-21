"""Left side of the controller: movement plus at most a short row of buttons."""
from src.core.controller_presets import ControllerPresetStore


def _store(tmp_path):
    return ControllerPresetStore(storage_path=tmp_path / "presets.json")


def test_left_buttons_capped_deduped_and_never_sticks(tmp_path):
    layout = _store(tmp_path)._normalize_layout({
        "leftButtons": ["btnlt", "LT", "RS_FIXED", "LB", "A"],
    })
    assert layout["leftButtons"] == ["LT", "LB"]


def test_left_buttons_are_always_visible(tmp_path):
    layout = _store(tmp_path)._normalize_layout({
        "visibleButtons": {"LT": False},
        "leftButtons": ["LT"],
    })
    assert layout["visibleButtons"]["LT"] is True


def test_old_layouts_have_no_left_buttons(tmp_path):
    layout = _store(tmp_path)._normalize_layout({"visibleButtons": {"A": True}})
    assert layout["leftButtons"] == []


def test_heave_ho_splits_triggers_between_hands(tmp_path):
    preset = _store(tmp_path).all_presets_by_id["game-heave-ho"]["layout"]
    assert preset["leftButtons"] == ["LT"]
    assert preset["visibleButtons"]["RT"] is True
    assert preset["visibleButtons"]["RS_FIXED"] is True
