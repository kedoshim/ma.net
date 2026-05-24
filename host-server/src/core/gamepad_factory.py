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
    """
    Send rumble events back to the client, with simple throttling and change detection.

    The vgamepad callback provides motor values which can be 0..255 or 0..65535 or already normalized.
    We normalize to 0.0..1.0 and map: small -> weak, large -> strong.
    """
    device_id = slot.assigned_device_id

    if not device_id:
        return

    # normalize helper
    def _norm(v):
        try:
            fv = float(v)
        except Exception:
            return 0.0
        if fv <= 1.0:
            return max(0.0, min(1.0, fv))
        if fv <= 255.0:
            return max(0.0, min(1.0, fv / 255.0))
        return max(0.0, min(1.0, fv / 65535.0))

    strong = _norm(large)
    weak = _norm(small)

    LOG.info("notify_rumble: device=%s large=%s small=%s", device_id, large, small)

    # Throttle: minimum interval between sends per-slot (seconds)
    min_interval = 0.15  # Approx 6-7 Hz to avoid network flooding while maintaining state
    now = asyncio.get_event_loop().time()

    # Only send when values change meaningfully
    def changed(a, b):
        return abs(a - b) > 0.03

    last_sent = getattr(slot, 'last_rumble_sent_at', 0.0)
    last_strong = getattr(slot, 'last_rumble_strong', 0.0)
    last_weak = getattr(slot, 'last_rumble_weak', 0.0)

    should_send = False
    if now - last_sent >= min_interval:
        if changed(strong, last_strong) or changed(weak, last_weak):
            should_send = True
        elif strong > 0.0 or weak > 0.0:
            # Keep sending active rumble periodically so the client doesn't time out
            should_send = True

    # If rumble stopped (both zero) and we previously had non-zero, ensure we send zero.
    if not should_send and strong == 0.0 and weak == 0.0 and (last_strong != 0.0 or last_weak != 0.0):
        should_send = True

    if not should_send:
        return

    ws = manager.get_ws_by_device(device_id)
    if not ws:
        return

    payload = {
        "type": "rumble",
        "weak": weak,
        "strong": strong,
    }

    try:
        await ws.send_json(payload)
        LOG.info("sent rumble -> device=%s payload=%s", device_id, payload)
        # update slot state
        slot.last_rumble_sent_at = now
        slot.last_rumble_strong = strong
        slot.last_rumble_weak = weak
    except Exception as e:
        LOG.error("Failed rumble notify: %s", e)


def create_gamepad(manager, config_type: str, existing_x360_count: int, main_loop, slot_index: int):
    if main_loop is None:
        raise RuntimeError("Main loop not initialized")

    def rumble_callback(client, target, large_motor, small_motor, led_number, user_data):
        if slot_index >= len(manager.slots):
            return
        slot = manager.slots[slot_index]

        if main_loop.is_closed():
            return

        try:
            LOG.info('rumble_callback: slot=%s large_motor=%s small_motor=%s', slot.slot_id, large_motor, small_motor)
            asyncio.run_coroutine_threadsafe(
                notify_rumble(manager, slot, large_motor, small_motor),
                main_loop
            )
        except Exception as e:
            LOG.error("Rumble callback failed: %s", e)

    gamepad_type = config_type

    if gamepad_type not in ("ds4", "x360"):
        total_xinput = count_xinput_connected()

        if total_xinput >= 8:
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