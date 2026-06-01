import json
import random
import logging
from pathlib import Path
from src.routes.file_routes import FileRoutes

LOGGER = logging.getLogger("name_generator")

class NameGenerator:
    _configs = {}

    @classmethod
    def load_config(cls, lang: str):
        lang = lang.lower().split("-")[0].split("_")[0]  # Normalize to 'pt', 'en' etc.
        if lang in cls._configs:
            return cls._configs[lang]

        # Resolve path using the helper that supports both dev and frozen mode
        config_path = Path(FileRoutes.get_resource_path(f"data/names/name_generator_{lang}.json"))
        if not config_path.exists():
            # Fallback to Portuguese if the specific language is not found
            config_path = Path(FileRoutes.get_resource_path("data/names/name_generator_pt.json"))

        if not config_path.exists():
            LOGGER.warning(f"Name generator config file not found at {config_path}. Using hardcoded fallback.")
            return {
                "pattern": "{noun} {adjective}",
                "nouns": ["Capivara", "Pamonha", "Pastel", "Tatu"],
                "adjectives": ["Radical", "Nervosa", "Brilhante", "Dançante"]
            }

        try:
            with open(config_path, "r", encoding="utf-8") as f:
                config = json.load(f)
                cls._configs[lang] = config
                return config
        except Exception as e:
            LOGGER.exception(f"Failed to load name generator config for {lang}: {e}")
            return {
                "pattern": "{noun} {adjective}",
                "nouns": ["Capivara", "Pamonha"],
                "adjectives": ["Radical", "Nervosa"]
            }

    @classmethod
    def generate(cls, lang: str) -> str:
        config = cls.load_config(lang)
        
        # Determine pattern
        patterns = config.get("patterns")
        if isinstance(patterns, list) and patterns:
            pattern = random.choice(patterns)
        else:
            pattern = config.get("pattern", "{noun} {adjective}")

        # Build format dictionary from all lists in config
        format_dict = {}
        for key, value in config.items():
            if isinstance(value, list) and value:
                # Plural key (e.g. "nouns") to singular placeholder (e.g. "noun")
                if key.endswith("s"):
                    singular = key[:-1]
                    format_dict[singular] = random.choice(value)
                else:
                    # In case they use singular key
                    format_dict[key] = random.choice(value)

        # Fallback defaults for standard placeholders in case lists are missing
        if "noun" not in format_dict:
            format_dict["noun"] = "Capivara"
        if "adjective" not in format_dict:
            format_dict["adjective"] = "Radical"
        if "animal" not in format_dict:
            format_dict["animal"] = "Capivara"
        if "food" not in format_dict:
            format_dict["food"] = "Pipoca"
        if "name" not in format_dict:
            format_dict["name"] = "Zezinho"

        try:
            return pattern.format(**format_dict)
        except Exception as e:
            LOGGER.error(f"Failed to format pattern '{pattern}': {e}")
            return f"{format_dict['noun']} {format_dict['adjective']}"
