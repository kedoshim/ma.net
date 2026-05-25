import asyncio
import sys
import ctypes
from ctypes import wintypes
import logging
import subprocess
import time
import vgamepad as vg

LOG = logging.getLogger(__name__)


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
            LOG.debug("XInput DLL not found: %s", name)

    if xinput is None:
        return 0

    try:
        XInputGetState = xinput.XInputGetState
        XInputGetState.argtypes = [wintypes.DWORD, ctypes.c_void_p]
        XInputGetState.restype = wintypes.DWORD
    except Exception:
        LOG.exception("Failed to bind XInputGetState")
        return 0

    connected = 0

    for i in range(4):
        buf = ctypes.create_string_buffer(128)
        try:
            res = XInputGetState(i, ctypes.byref(buf))
            if res == 0:
                connected += 1
        except Exception:
            LOG.debug("XInputGetState call failed for index %d", i)

    return connected


def probe_gamepad_type(gamepad_type: str, timeout: float = 5.0) -> bool:
    """
    Probe in a subprocess whether creating a gamepad of `gamepad_type` succeeds.
    This isolates native crashes to the child process and prevents the main
    server from dying when a gamepad creation would trigger a native fault.
    """
    cmd = [sys.executable, "-c"]
    if gamepad_type == "ds4":
        code = "import vgamepad as vg; g=vg.VDS4Gamepad(); print('ok')"
    else:
        code = "import vgamepad as vg; g=vg.VX360Gamepad(); print('ok')"

    try:
        proc = subprocess.run(cmd + [code], capture_output=True, timeout=timeout)
        return proc.returncode == 0
    except subprocess.TimeoutExpired:
        return False
    except Exception:
        LOG.exception("Probe subprocess failed for gamepad_type=%s", gamepad_type)
        return False


class NullGamepad:
    """Fallback no-op gamepad used when real gamepad creation is unsafe.

    Methods match those used by the codebase (`reset`, `update`,
    `register_notification`) so the rest of the system can continue
    functioning without native handles.
    """
    def reset(self):
        return

    def update(self):
        return

    def register_notification(self, callback_function=None):
        return

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

    LOG.debug("notify_rumble: device=%s large=%s small=%s", device_id, large, small)

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
        LOG.exception("Failed rumble notify for device=%s", device_id)


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
            # LOG.info('rumble_callback: slot=%s large_motor=%s small_motor=%s', slot.slot_id, large_motor, small_motor)
            asyncio.run_coroutine_threadsafe(
                notify_rumble(manager, slot, large_motor, small_motor),
                main_loop
            )
        except Exception as e:
            LOG.exception("Rumble callback failed for slot=%s", getattr(slot, 'slot_id', None))

    gamepad_type = config_type

    if gamepad_type not in ("ds4", "x360"):
        total_xinput = count_xinput_connected()

        if total_xinput >= 8:
            LOG.debug("XInput limit reached. Falling back to DS4.")
            gamepad_type = "ds4"
        else:
            gamepad_type = "x360"

    if gamepad_type == "ds4":
        # Probe creation in a child process first to avoid native crashes
        ok = probe_gamepad_type("ds4")
        if not ok:
            LOG.error("Probe failed: DS4 gamepad creation is unsafe on this system")
            # Return a NullGamepad to keep the server alive; callers should
            # handle the fact that rumble/notifications won't work for this slot.
            return NullGamepad(), "ds4"

        try:
            gamepad = vg.VDS4Gamepad()
        except Exception:
            LOG.exception("Failed to create DS4 gamepad after probe")
            # Fallback to NullGamepad on unexpected exception
            return NullGamepad(), "ds4"
    else:
        try:
            gamepad = vg.VX360Gamepad()
        except Exception:
            LOG.exception("Failed to create X360 gamepad")
            # X360 creation is generally safer; if it fails, return NullGamepad
            return NullGamepad(), "x360"

    gamepad.register_notification(
        callback_function=rumble_callback
    )

    return gamepad, gamepad_type