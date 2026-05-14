import random

DEFAULT_FACE_TEXT = ":)"
DEFAULT_ROTATION = "normal"

FACE_PALETTE = [
    "#FF6B6B",
    "#FFA94D",
    "#FFE066",
    "#8CE99A",
    "#66D9E8",
    "#74C0FC",
    "#A78BFA",
    "#F783AC",
]

FACE_PRESETS = [
    {
        "id": "happy",
        "label": "happy",
        "faceText": ":)",
        "faceRotation": "normal",
        "color": "#FFE066",
    },
    {
        "id": "angry",
        "label": "angry",
        "faceText": ">:(",
        "faceRotation": "normal",
        "color": "#FF6B6B",
    },
    {
        "id": "confused",
        "label": "confused",
        "faceText": ":/",
        "faceRotation": "right_vertical",
        "color": "#74C0FC",
    },
    {
        "id": "silly",
        "label": "silly",
        "faceText": ":P",
        "faceRotation": "normal",
        "color": "#8CE99A",
    },
    {
        "id": "deadpan",
        "label": "deadpan",
        "faceText": "-_-",
        "faceRotation": "normal",
        "color": "#A78BFA",
    },
    {
        "id": "cursed",
        "label": "cursed",
        "faceText": "OwO",
        "faceRotation": "upside_down",
        "color": "#F783AC",
    },
]


def sanitize_face_text(value):
    if value is None:
        return DEFAULT_FACE_TEXT
    cleaned = "".join(value.splitlines()).replace('\t', '')
    truncated = "".join(list(cleaned)[:3])
    return truncated


def normalize_rotation(value):
    valid = {"normal", "upside_down", "left_vertical", "right_vertical"}
    return value if value in valid else DEFAULT_ROTATION


def get_preset_by_id(preset_id):
    for preset in FACE_PRESETS:
        if preset["id"] == preset_id:
            return preset
    return None


def random_identity():
    preset = random.choice(FACE_PRESETS)
    color = random.choice(FACE_PALETTE)
    return {
        "color": color,
        "faceText": preset["faceText"],
        "faceRotation": preset["faceRotation"],
        "presetId": preset["id"],
    }


def normalize_identity(customization=None, fallback=None):
    fallback = fallback or random_identity()
    customization = customization or {}
    preset_id = customization.get("presetId") if "presetId" in customization else fallback.get("presetId")
    preset = get_preset_by_id(preset_id)
    color = customization.get("color")
    if not color and preset is not None:
        color = preset.get("color")
    if not color:
        color = fallback.get("color")
    face_text = customization.get("faceText")
    if face_text is None and "faceText" not in customization:
        face_text = preset.get("faceText") if preset else fallback.get("faceText")

    face_rotation = customization.get("faceRotation")
    if not face_rotation:
        face_rotation = preset.get("faceRotation") if preset else fallback.get("faceRotation")

    return {
        "color": color,
        "faceText": sanitize_face_text(face_text),
        "faceRotation": normalize_rotation(face_rotation),
        "presetId": preset_id,
    }
