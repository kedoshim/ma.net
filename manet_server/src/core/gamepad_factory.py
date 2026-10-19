import asyncio
import sys
import ctypes
from ctypes import wintypes
import logging
import subprocess
import threading
import time
import vgamepad as vg
import vgamepad.win.vigem_client as vcli

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
    frozen = getattr(sys, 'frozen', False)
    if frozen:
        cmd = [sys.executable, f"--probe-{gamepad_type}"]
    else:
        cmd = [sys.executable, "-c"]
        if gamepad_type == "ds4":
            code = "import vgamepad as vg; g=vg.VDS4Gamepad(); print('ok')"
        else:
            code = "import vgamepad as vg; g=vg.VX360Gamepad(); print('ok')"
        cmd.append(code)

    try:
        proc = subprocess.run(cmd, capture_output=True, timeout=timeout)
        return proc.returncode == 0
    except subprocess.TimeoutExpired:
        return False
    except Exception:
        LOG.exception("Probe subprocess failed for gamepad_type=%s", gamepad_type)
        return False


# Gamepads that were unplugged but whose native target is deliberately never
# freed. ViGEmClient's notification thread keeps using a target after
# unregister_notification(); freeing it (vgamepad's __del__ calls
# vigem_target_free) makes that thread touch freed memory, which crashed the
# whole server with an access violation when switching XInput <-> DInput.
# Leaking a few hundred bytes per retired pad is the safe trade-off.
_retired_gamepads: list = []
_retired_classes: dict[type, type] = {}


def _retired_class_for(cls):
    retired = _retired_classes.get(cls)
    if retired is None:
        retired = type(f"Retired{cls.__name__}", (cls,), {"__del__": lambda self: None})
        _retired_classes[cls] = retired
    return retired


def retire_gamepad(gamepad):
    """Unplug a virtual gamepad from Windows without freeing its native target."""
    if gamepad is None or isinstance(gamepad, NullGamepad):
        return
    state = getattr(gamepad, "_manet_callback_state", None)
    if state is not None:
        state["alive"] = False
    try:
        gamepad.unregister_notification()
    except Exception:
        LOG.exception("Failed to unregister gamepad notification")
    try:
        gamepad.reset()
        gamepad.update()
    except Exception:
        LOG.exception("Failed to reset gamepad before retiring")
    try:
        vcli.vigem_target_remove(gamepad._busp, gamepad._devicep)
    except Exception:
        LOG.exception("Failed to unplug gamepad target")
    # Swap in a subclass whose __del__ is a no-op so the target is never freed,
    # and keep the object (and its ctypes callback thunk) alive.
    gamepad.__class__ = _retired_class_for(type(gamepad))
    _retired_gamepads.append(gamepad)


_PROBE_FAILURE_TTL = 30.0
_probe_cache: dict[str, tuple[bool, float]] = {}
_probe_lock = threading.Lock()


def probe_gamepad_type_cached(gamepad_type: str) -> bool:
    """
    Run the crash-isolation probe at most once per process for each type.

    The probe launches a whole child process (in the frozen build: the server
    exe itself), so probing per slot used to cost seconds. Successes are cached
    forever; failures are retried after a short TTL in case the driver was
    still warming up.
    """
    with _probe_lock:
        cached = _probe_cache.get(gamepad_type)
        if cached is not None:
            ok, at = cached
            if ok or time.monotonic() - at < _PROBE_FAILURE_TTL:
                return ok
        ok = probe_gamepad_type(gamepad_type)
        _probe_cache[gamepad_type] = (ok, time.monotonic())
        LOG.info("Gamepad probe for %s: %s", gamepad_type, "ok" if ok else "failed")
        return ok


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
    
    def unregister_notification(self):
        return

    def __getattr__(self, name):
        def _no_op(*args, **kwargs):
            pass
        return _no_op

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
        LOG.debug("sent rumble -> device=%s payload=%s", device_id, payload)
        # update slot state
        slot.last_rumble_sent_at = now
        slot.last_rumble_strong = strong
        slot.last_rumble_weak = weak
    except Exception as e:
        LOG.exception("Failed rumble notify for device=%s", device_id)


def create_gamepad(manager, config_type: str, existing_x360_count: int, main_loop, slot_index: int):
    
    if main_loop is None:
        raise RuntimeError("Main loop not initialized")

    LOGGER_CM = logging.getLogger("gamepad_factory")
    LOGGER_CM.info("[GAMEPAD_FACTORY] Request to create gamepad: slot_index=%d, config_type=%s, existing_x360_count=%d", 
                  slot_index, config_type, existing_x360_count)

    # slot_index lives in the state: pads can be handed to other seats later
    # (ControllerManager.order_pads_for_games).
    callback_state = {"alive": True, "slot_index": slot_index}

    def rumble_callback(client, target, large_motor, small_motor, led_number, user_data):
        if not callback_state["alive"]:
            return
        slot_index = callback_state["slot_index"]
        callback_state["last_large"] = large_motor
        if callback_state.get("probing"):
            # The controllers panel is identifying XInput slots with a
            # signature vibration; don't buzz the phone for it.
            return
        if slot_index >= len(manager.slots):
            LOG.debug("[GAMEPAD_FACTORY] Rumble callback ignored: slot_index %d is out of bounds (total slots: %d)", slot_index, len(manager.slots))
            return
        slot = manager.slots[slot_index]

        if main_loop.is_closed():
            LOG.debug("[GAMEPAD_FACTORY] Rumble callback ignored: main loop closed")
            return

        try:
            # LOG.info('rumble_callback: slot=%s large_motor=%s small_motor=%s', slot.slot_id, large_motor, small_motor)
            asyncio.run_coroutine_threadsafe(
                notify_rumble(manager, slot, large_motor, small_motor),
                main_loop
            )
        except Exception as e:
            LOG.exception("[GAMEPAD_FACTORY] Rumble callback failed for slot=%s", getattr(slot, 'slot_id', None))

    gamepad_type = config_type

    if gamepad_type not in ("ds4", "x360"):
        total_xinput = count_xinput_connected()
        LOGGER_CM.info("[GAMEPAD_FACTORY] Mixed mode active. Checked connected XInput devices: %d", total_xinput)

        if total_xinput >= 8:
            LOG.debug("[GAMEPAD_FACTORY] XInput limit reached. Falling back to DS4.")
            gamepad_type = "ds4"
        else:
            gamepad_type = "x360"

    LOGGER_CM.info("[GAMEPAD_FACTORY] Resolving gamepad type: %s", gamepad_type)

    if gamepad_type == "ds4":
        # Probe creation in a child process first to avoid native crashes
        LOGGER_CM.info("[GAMEPAD_FACTORY] Probing DS4 gamepad safety...")
        ok = probe_gamepad_type_cached("ds4")
        if not ok:
            LOG.error("[GAMEPAD_FACTORY] Probe failed: DS4 gamepad creation is unsafe on this system. Falling back to NullGamepad.")
            # Return a NullGamepad to keep the server alive; callers should
            # handle the fact that rumble/notifications won't work for this slot.
            return NullGamepad(), "ds4"

        try:
            LOGGER_CM.info("[GAMEPAD_FACTORY] Instantiating VDS4Gamepad...")
            gamepad = vg.VDS4Gamepad()
        except Exception:
            LOG.exception("[GAMEPAD_FACTORY] Failed to create DS4 gamepad after probe. Falling back to NullGamepad.")
            # Fallback to NullGamepad on unexpected exception
            return NullGamepad(), "ds4"
    else:
        try:
            LOGGER_CM.info("[GAMEPAD_FACTORY] Instantiating VX360Gamepad...")
            gamepad = vg.VX360Gamepad()
        except Exception:
            LOG.exception("[GAMEPAD_FACTORY] Failed to create X360 gamepad. Falling back to NullGamepad.")
            # X360 creation is generally safer; if it fails, return NullGamepad
            return NullGamepad(), "x360"

    try:
        LOGGER_CM.info("[GAMEPAD_FACTORY] Registering native rumble callback for slot %d", slot_index)
        gamepad._manet_callback_state = callback_state
        gamepad.register_notification(
            callback_function=rumble_callback
        )
    except Exception:
        LOG.exception("[GAMEPAD_FACTORY] Failed to register notification callback for slot %d", slot_index)

    LOG.info("[GAMEPAD_FACTORY] Successfully created %s gamepad for slot %s", gamepad_type, slot_index)
    return gamepad, gamepad_type