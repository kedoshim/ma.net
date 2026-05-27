import vgamepad as vg
from src.input.input_mapper import (
    XINPUT_BUTTON_MAP,
    DS4_BUTTON_MAP,
)

DS4_DPAD_BUTTONS = {
    vg.DS4_DPAD_DIRECTIONS.DS4_BUTTON_DPAD_NORTH,
    vg.DS4_DPAD_DIRECTIONS.DS4_BUTTON_DPAD_SOUTH,
    vg.DS4_DPAD_DIRECTIONS.DS4_BUTTON_DPAD_WEST,
    vg.DS4_DPAD_DIRECTIONS.DS4_BUTTON_DPAD_EAST,
}


def apply_stick(slot, x, y):
    if slot.controller_type == "ds4":
        y = -y

    slot.gamepad.left_joystick_float(
        x_value_float=x,
        y_value_float=y
    )
    slot.gamepad.update()


def apply_button(slot, btn, state):
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

        gp.update()
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

        gp.update()
        return

    if btn not in XINPUT_BUTTON_MAP:
        return

    if state == "down":
        gp.press_button(button=XINPUT_BUTTON_MAP[btn])
    else:
        gp.release_button(button=XINPUT_BUTTON_MAP[btn])

    gp.update()