import json
import string
from pathlib import Path

import pytest

from src.core.name_generator import NameGenerator

NAMES_DIR = Path(__file__).resolve().parents[1] / "data" / "names"


def _placeholders(config: dict) -> set[str]:
    """The keys the generator builds from the lists (plural -> singular)."""
    keys = set()
    for key, value in config.items():
        if not isinstance(value, list) or key == "patterns":
            continue
        if key[-2:] in ("_m", "_f"):
            base = key[:-2]
            keys.add((base[:-1] if base.endswith("s") else base) + key[-2:])
        else:
            keys.add(key[:-1] if key.endswith("s") else key)
    return keys


@pytest.mark.parametrize("path", sorted(NAMES_DIR.glob("name_generator_*.json")), ids=lambda p: p.stem)
def test_every_pattern_uses_known_placeholders(path):
    config = json.loads(path.read_text(encoding="utf-8"))
    known = _placeholders(config)
    patterns = config.get("patterns") or [config.get("pattern")]
    for pattern in patterns:
        fields = {field for _, field, _, _ in string.Formatter().parse(pattern) if field}
        assert fields <= known, f"{pattern!r} uses {fields - known}"


@pytest.mark.parametrize("lang", ["pt", "en"])
def test_generated_names_fit(lang):
    for _ in range(200):
        name = NameGenerator.generate(lang)
        assert name and len(name) <= 15
