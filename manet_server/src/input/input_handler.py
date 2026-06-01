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
        LOG.info("Updating virtual gamepad")
        gp.update()
        LOG.info("Input applied successfully")
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


def apply_button(slot, btn, state):
    if not hasattr(slot, "gamepad") or slot.gamepad is None:
        LOG.warning("Attempted to apply button %s to slot %s, but gamepad is missing or deleted", btn, getattr(slot, 'slot_id', 'unknown'))
        return
    gp = slot.gamepad

    if slot.controller_type == "ds4":
        if btn not in DS4_BUTTON_MAP:
            return

        const = DS4_BUTTON_MAP[btn]

        if state == "down":
            if const in DS4_DPAD_BUTTONS:
                gp.directional_pad(const)
            else:
                gp.press_button(button=const)
        else:
            try:
                gp.release_button(button=const)
            except Exception:
                pass
            gp.reset()

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