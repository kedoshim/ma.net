import asyncio
import sys
import ctypes
from ctypes import wintypes
import logging
import vgamepad as vg

LOG = logging.getLogger("piko-proto")


def count_xinput_connected():
    if sys.platform != "win32":
        return 0

    dll_names = [
        "xinput1_4.dll",
        "xinput1_3.dll",
        "xinput9_1_0.dll",
    ]

    xinput = None

    for name in dll_names:
        try:
            xinput = ctypes.WinDLL(name)
            break
        except Exception:
            pass

    if xinput is None:
        return 0

    try:
        XInputGetState = xinput.XInputGetState
        XInputGetState.argtypes = [wintypes.DWORD, ctypes.c_void_p]
        XInputGetState.restype = wintypes.DWORD
    except Exception:
        return 0

    connected = 0

    for i in range(4):
        buf = ctypes.create_string_buffer(128)
        try:
            res = XInputGetState(i, ctypes.byref(buf))
            if res == 0:
                connected += 1
        except Exception:
            pass

    return connected

async def notify_rumble(manager, slot, large, small):
    device_id = slot.assigned_device_id

    if not device_id:
        return

    ws = manager.get_ws_by_device(device_id)

    if not ws:
        return

    try:
        await ws.send_json({
            "type": "rumble",
            "large": large,
            "small": small
        })
    except Exception as e:
        LOG.error("Failed rumble notify: %s", e)


def create_gamepad(manager, config_type: str, existing_x360_count: int, main_loop):
    if main_loop is None:
        raise RuntimeError("Main loop not initialized")

    def rumble_callback(client, target, large_motor, small_motor, led_number, user_data):
        slot = user_data

        if main_loop.is_closed():
            return

        try:
            asyncio.run_coroutine_threadsafe(
                notify_rumble(manager, slot, large_motor, small_motor),
                main_loop
            )
        except Exception as e:
            LOG.error("Rumble callback failed: %s", e)

    gamepad_type = config_type

    if gamepad_type not in ("ds4", "x360"):
        total_xinput = count_xinput_connected()

        if total_xinput >= 4:
            LOG.debug("XInput limit reached. Falling back to DS4.")
            gamepad_type = "ds4"
        else:
            gamepad_type = "x360"

    if gamepad_type == "ds4":
        try:
            gamepad = vg.VDS4Gamepad()
        except Exception as e:
            LOG.error("Failed to create DS4 gamepad: %s", e)
            raise
    else:
        try:
            gamepad = vg.VX360Gamepad()
        except Exception as e:
            LOG.error("Failed to create X360 gamepad: %s", e)
            raise

    gamepad.register_notification(
        callback_function=rumble_callback
    )

    return gamepad, gamepad_type