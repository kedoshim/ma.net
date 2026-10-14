import logging
import vgamepad as vg
from src.input.input_mapper import (
    XINPUT_BUTTON_MAP,
    DS4_BUTTON_MAP,
)

LOG = logging.getLogger(__name__)

DS4_DPAD_BUTTONS = {
    vg.DS4_DPAD_DIRECTIONS.DS4_BUTTON_DPAD_NORTH,
    vg.DS4_DPAD_DIRECTIONS.DS4_BUTTON_DPAD_SOUTH,
    vg.DS4_DPAD_DIRECTIONS.DS4_BUTTON_DPAD_WEST,
    vg.DS4_DPAD_DIRECTIONS.DS4_BUTTON_DPAD_EAST,
}


def _update_gamepad_safe(gp):
    try:
        gp.update()
    except Exception:
        LOG.exception("Failed to update virtual gamepad")
        raise


def apply_stick(slot, x, y):
    if not hasattr(slot, "gamepad") or slot.gamepad is None:
        LOG.warning("Attempted to apply stick to slot %s, but gamepad is missing or deleted", getattr(slot, 'slot_id', 'unknown'))
        return

    if slot.controller_type == "ds4":
        y = -y

    slot.gamepad.left_joystick_float(
        x_value_float=x,
        y_value_float=y
    )
    _update_gamepad_safe(slot.gamepad)


def apply_right_stick(slot, x, y):
    if not hasattr(slot, "gamepad") or slot.gamepad is None:
        LOG.warning("Attempted to apply right stick to slot %s, but gamepad is missing or deleted", getattr(slot, 'slot_id', 'unknown'))
        return

    if slot.controller_type == "ds4":
        y = -y

    slot.gamepad.right_joystick_float(
        x_value_float=x,
        y_value_float=y
    )
    _update_gamepad_safe(slot.gamepad)


def apply_trigger(slot, btn, value):
    """Analog LT/RT (0..1) from a physical pad relayed by a phone."""
    if not hasattr(slot, "gamepad") or slot.gamepad is None:
        return
    gp = slot.gamepad
    value = max(0.0, min(1.0, value))

    if btn == "LT":
        gp.left_trigger_float(value)
    elif btn == "RT":
        gp.right_trigger_float(value)
    else:
        return

    if slot.controller_type == "ds4":
        # DS4 triggers also carry a digital bit; keep it in sync.
        const = DS4_BUTTON_MAP[btn]
        if value > 0.1:
            gp.press_button(button=const)
        else:
            try:
                gp.release_button(button=const)
            except Exception:
                LOG.debug("Failed to release DS4 trigger bit %s", btn)

    _update_gamepad_safe(gp)


def apply_button(slot, btn, state):
    if not hasattr(slot, "gamepad") or slot.gamepad is None:
        LOG.warning("Attempted to apply button %s to slot %s, but gamepad is missing or deleted", btn, getattr(slot, 'slot_id', 'unknown'))
        return
    gp = slot.gamepad

    if slot.controller_type == "ds4":
        if btn in {"UP", "DOWN", "LEFT", "RIGHT"}:
            if not hasattr(slot, "active_dpad"):
                slot.active_dpad = set()

            if state == "down":
                slot.active_dpad.add(btn)
            else:
                slot.active_dpad.discard(btn)

            has_up = "UP" in slot.active_dpad
            has_down = "DOWN" in slot.active_dpad
            has_left = "LEFT" in slot.active_dpad
            has_right = "RIGHT" in slot.active_dpad

            # Cancel out opposite inputs
            if has_up and has_down:
                has_up = False
                has_down = False
            if has_left and has_right:
                has_left = False
                has_right = False

            if has_up and has_left:
                dpad_val = vg.DS4_DPAD_DIRECTIONS.DS4_BUTTON_DPAD_NORTHWEST
            elif has_up and has_right:
                dpad_val = vg.DS4_DPAD_DIRECTIONS.DS4_BUTTON_DPAD_NORTHEAST
            elif has_down and has_left:
                dpad_val = vg.DS4_DPAD_DIRECTIONS.DS4_BUTTON_DPAD_SOUTHWEST
            elif has_down and has_right:
                dpad_val = vg.DS4_DPAD_DIRECTIONS.DS4_BUTTON_DPAD_SOUTHEAST
            elif has_up:
                dpad_val = vg.DS4_DPAD_DIRECTIONS.DS4_BUTTON_DPAD_NORTH
            elif has_down:
                dpad_val = vg.DS4_DPAD_DIRECTIONS.DS4_BUTTON_DPAD_SOUTH
            elif has_left:
                dpad_val = vg.DS4_DPAD_DIRECTIONS.DS4_BUTTON_DPAD_WEST
            elif has_right:
                dpad_val = vg.DS4_DPAD_DIRECTIONS.DS4_BUTTON_DPAD_EAST
            else:
                dpad_val = vg.DS4_DPAD_DIRECTIONS.DS4_BUTTON_DPAD_NONE

            gp.directional_pad(dpad_val)
            _update_gamepad_safe(gp)
            return

        if btn not in DS4_BUTTON_MAP:
            return

        const = DS4_BUTTON_MAP[btn]

        # DS4 triggers have both a digital bit and an analog axis; keep them in sync.
        if btn == "LT":
            gp.left_trigger_float(1.0 if state == "down" else 0.0)
        elif btn == "RT":
            gp.right_trigger_float(1.0 if state == "down" else 0.0)

        if state == "down":
            gp.press_button(button=const)
        else:
            try:
                gp.release_button(button=const)
            except Exception:
                LOG.debug("Failed to release DS4 button %s", btn)

        _update_gamepad_safe(gp)
        return

    if btn in {"RT", "LT"}:
        if btn == "RT":
            if state == "down":
                gp.right_trigger_float(1.0)
            else:
                gp.right_trigger_float(0.0)
        else:
            if state == "down":
                gp.left_trigger_float(1.0)
            else:
                gp.left_trigger_float(0.0)

        _update_gamepad_safe(gp)
        return

    if btn not in XINPUT_BUTTON_MAP:
        return

    if state == "down":
        gp.press_button(button=XINPUT_BUTTON_MAP[btn])
    else:
        gp.release_button(button=XINPUT_BUTTON_MAP[btn])

    _update_gamepad_safe(gp)