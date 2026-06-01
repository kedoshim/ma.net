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
        # Try up to 20 times to generate a name under 15 characters
        for _ in range(20):
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
                    # Plural key (e.g. "nouns", "nouns_m", "nouns_f") to singular placeholder
                    # Let's handle keys like "nouns_m" -> "noun_m"
                    singular = key
                    if key.endswith("_m") or key.endswith("_f"):
                        gender_suffix = key[-2:]  # "_m" or "_f"
                        base = key[:-2]
                        if base.endswith("s"):
                            singular = base[:-1] + gender_suffix
                    elif key.endswith("s"):
                        singular = key[:-1]
                    
                    format_dict[singular] = random.choice(value)

            # Fallback defaults for standard and gendered placeholders in case lists are missing
            for suffix in ["", "_m", "_f"]:
                if f"noun{suffix}" not in format_dict:
                    format_dict[f"noun{suffix}"] = "Capivara" if suffix == "_f" else "Pastel"
                if f"adjective{suffix}" not in format_dict:
                    format_dict[f"adjective{suffix}"] = "Nervosa" if suffix == "_f" else "Radical"
                if f"animal{suffix}" not in format_dict:
                    format_dict[f"animal{suffix}"] = "Capivara" if suffix == "_f" else "Tatu"
                if f"food{suffix}" not in format_dict:
                    format_dict[f"food{suffix}"] = "Pipoca" if suffix == "_f" else "Pastel"
                if f"name{suffix}" not in format_dict:
                    format_dict[f"name{suffix}"] = "Cida" if suffix == "_f" else "Zezinho"

            try:
                name = pattern.format(**format_dict)
                if len(name) <= 15:
                    return name
            except Exception as e:
                LOGGER.error(f"Failed to format pattern '{pattern}': {e}")
                fallback = f"{format_dict['noun']} {format_dict['adjective']}"
                if len(fallback) <= 15:
                    return fallback

        # Last resort fallback: generate one last time and truncate to 15 characters
        try:
            config = cls.load_config(lang)
            # Pick a short fallback
            return f"{format_dict['noun']} {format_dict['adjective']}"[:15].strip()
        except:
            return "Capivara"

