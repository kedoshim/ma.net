"""
What Windows actually sees as game controllers, so the host can spot pads
that are not MaNet's (real controllers, Steam/DS4Windows virtual pads, or
leftovers from an old session) and XInput slots already taken by them.

Uses CfgMgr32 directly: enumerating via PowerShell took several seconds.
"""
import ctypes
import logging
import os
import sys
import threading
import time
from ctypes import wintypes

import psutil

LOG = logging.getLogger(__name__)

XINPUT_MAX_USERS = 4

_CR_SUCCESS = 0
_CR_BUFFER_SMALL = 0x1A
_CM_GETIDLIST_FILTER_PRESENT = 0x100
_CM_DRP_DEVICEDESC = 0x1
_CM_DRP_HARDWAREID = 0x2
_CM_DRP_COMPATIBLEIDS = 0x3
_CM_DRP_CLASS = 0x8
_CM_DRP_FRIENDLYNAME = 0xD

_XINPUT_COMPOSITE_CLASSES = {"xnacomposite", "xboxcomposite"}


def _load_cfgmgr():
    if sys.platform != "win32":
        return None
    try:
        cfg = ctypes.WinDLL("cfgmgr32.dll")
    except OSError:
        return None
    cfg.CM_Get_Device_ID_List_SizeW.argtypes = [ctypes.POINTER(wintypes.ULONG), wintypes.LPCWSTR, wintypes.ULONG]
    cfg.CM_Get_Device_ID_ListW.argtypes = [wintypes.LPCWSTR, wintypes.LPWSTR, wintypes.ULONG, wintypes.ULONG]
    cfg.CM_Locate_DevNodeW.argtypes = [ctypes.POINTER(wintypes.DWORD), wintypes.LPCWSTR, wintypes.ULONG]
    cfg.CM_Get_Parent.argtypes = [ctypes.POINTER(wintypes.DWORD), wintypes.DWORD, wintypes.ULONG]
    cfg.CM_Get_Device_IDW.argtypes = [wintypes.DWORD, wintypes.LPWSTR, wintypes.ULONG, wintypes.ULONG]
    cfg.CM_Get_DevNode_Registry_PropertyW.argtypes = [
        wintypes.DWORD, wintypes.ULONG, ctypes.POINTER(wintypes.ULONG),
        ctypes.c_void_p, ctypes.POINTER(wintypes.ULONG), wintypes.ULONG,
    ]
    return cfg


_cfg = _load_cfgmgr()


def _present_device_ids() -> list[str]:
    size = wintypes.ULONG(0)
    if _cfg.CM_Get_Device_ID_List_SizeW(ctypes.byref(size), None, _CM_GETIDLIST_FILTER_PRESENT) != _CR_SUCCESS:
        return []
    buf = ctypes.create_unicode_buffer(size.value)
    if _cfg.CM_Get_Device_ID_ListW(None, buf, size.value, _CM_GETIDLIST_FILTER_PRESENT) != _CR_SUCCESS:
        return []
    return [item for item in ctypes.wstring_at(buf, size.value).split("\0") if item]


def _locate(device_id: str):
    devinst = wintypes.DWORD(0)
    if _cfg.CM_Locate_DevNodeW(ctypes.byref(devinst), device_id, 0) != _CR_SUCCESS:
        return None
    return devinst.value


def _parent(devinst: int):
    parent = wintypes.DWORD(0)
    if _cfg.CM_Get_Parent(ctypes.byref(parent), devinst, 0) != _CR_SUCCESS:
        return None
    return parent.value


def _device_id(devinst: int) -> str:
    buf = ctypes.create_unicode_buffer(512)
    if _cfg.CM_Get_Device_IDW(devinst, buf, 512, 0) != _CR_SUCCESS:
        return ""
    return buf.value


def _property(devinst: int, prop: int) -> list[str]:
    """Registry property as a list of strings (REG_SZ or REG_MULTI_SZ)."""
    length = wintypes.ULONG(0)
    reg_type = wintypes.ULONG(0)
    res = _cfg.CM_Get_DevNode_Registry_PropertyW(devinst, prop, ctypes.byref(reg_type), None, ctypes.byref(length), 0)
    if res not in (_CR_SUCCESS, _CR_BUFFER_SMALL) or length.value == 0:
        return []
    buf = ctypes.create_string_buffer(length.value)
    if _cfg.CM_Get_DevNode_Registry_PropertyW(devinst, prop, ctypes.byref(reg_type), buf, ctypes.byref(length), 0) != _CR_SUCCESS:
        return []
    text = buf.raw[:length.value].decode("utf-16-le", errors="ignore")
    return [item for item in text.split("\0") if item]


def _first(devinst: int, *props: int) -> str:
    for prop in props:
        values = _property(devinst, prop)
        if values:
            return values[0]
    return ""


def _origin(devinst: int) -> str:
    """'vigem', 'steam' or 'physical', by walking up the device tree."""
    node = devinst
    for _ in range(5):
        hardware_ids = " ".join(_property(node, _CM_DRP_HARDWAREID)).lower()
        device_id = _device_id(node).lower()
        if "vigembus" in hardware_ids or "vigembus" in device_id:
            return "vigem"
        if "vid_28de" in device_id or "vid_28de" in hardware_ids:
            return "steam"
        parent = _parent(node)
        if parent is None:
            break
        node = parent
    return "physical"


def _vendor(device_id: str) -> str:
    upper = device_id.upper()
    if "VID_054C" in upper:
        return "playstation"
    if "VID_045E" in upper:
        return "xbox"
    if "VID_057E" in upper:
        return "nintendo"
    if "VID_28DE" in upper:
        return "steam"
    return "generic"


def _owning_device(hid_devinst: int) -> int:
    """The device a gamepad HID node belongs to, skipping USB interface
    nodes, so one pad is reported once (an X360 pad is composite device ->
    IG_ interface -> HID node)."""
    node = _parent(hid_devinst)
    if node is None:
        return hid_devinst
    for _ in range(3):
        device_class = _first(node, _CM_DRP_CLASS).lower()
        device_id = _device_id(node).upper()
        is_interface = "&IG_" in device_id or "&MI_" in device_id
        if device_class in _XINPUT_COMPOSITE_CLASSES or not is_interface:
            return node
        parent = _parent(node)
        if parent is None:
            return node
        node = parent
    return node


def list_game_controllers() -> list[dict]:
    """Every game controller Windows reports as present, one entry per device."""
    if _cfg is None:
        return []

    controllers: dict[int, dict] = {}
    for device_id in _present_device_ids():
        upper = device_id.upper()
        devinst = None
        api = None
        if upper.startswith("HID\\"):
            devinst = _locate(device_id)
            if devinst is None:
                continue
            ids = [
                c.upper()
                for c in _property(devinst, _CM_DRP_HARDWAREID) + _property(devinst, _CM_DRP_COMPATIBLEIDS)
            ]
            if "HID_DEVICE_SYSTEM_GAME" not in ids:
                continue
            api = "xinput" if "&IG_" in upper else "dinput"
            owner = _owning_device(devinst)
        else:
            # Wired Xbox One/Series pads (GIP) may not expose a HID gamepad.
            devinst = _locate(device_id)
            if devinst is None:
                continue
            device_class = _first(devinst, _CM_DRP_CLASS).lower()
            if device_class not in _XINPUT_COMPOSITE_CLASSES:
                continue
            api = "xinput"
            owner = devinst

        existing = controllers.get(owner)
        if existing is not None:
            if api == "xinput":
                existing["api"] = "xinput"
            continue

        owner_id = _device_id(owner) or device_id
        controllers[owner] = {
            "name": _first(owner, _CM_DRP_FRIENDLYNAME, _CM_DRP_DEVICEDESC)
                    or _first(devinst, _CM_DRP_FRIENDLYNAME, _CM_DRP_DEVICEDESC),
            "instanceId": owner_id,
            "api": api,
            "origin": _origin(owner),
            "vendor": _vendor(owner_id),
        }

    return list(controllers.values())


def xinput_connected_indices() -> list[int]:
    if sys.platform != "win32":
        return []
    for name in ("xinput1_4.dll", "xinput1_3.dll", "xinput9_1_0.dll"):
        try:
            xinput = ctypes.WinDLL(name)
            break
        except OSError:
            continue
    else:
        return []
    get_state = xinput.XInputGetState
    get_state.argtypes = [wintypes.DWORD, ctypes.c_void_p]
    get_state.restype = wintypes.DWORD
    connected = []
    for i in range(XINPUT_MAX_USERS):
        buf = ctypes.create_string_buffer(16)
        if get_state(i, buf) == 0:
            connected.append(i)
    return connected


class _XInputVibration(ctypes.Structure):
    _fields_ = [("left", wintypes.WORD), ("right", wintypes.WORD)]


_probe_lock = threading.Lock()


def _xinput_set_state():
    for name in ("xinput1_4.dll", "xinput1_3.dll", "xinput9_1_0.dll"):
        try:
            fn = ctypes.WinDLL(name).XInputSetState
        except (OSError, AttributeError):
            continue
        fn.argtypes = [wintypes.DWORD, ctypes.POINTER(_XInputVibration)]
        fn.restype = wintypes.DWORD
        return fn
    return None


def probe_xinput_indices(callback_states: dict[int, dict], connected: list[int]) -> dict[int, int]:
    """Which XInput slot (0-3) each of our X360 pads got, as {slot_id: index}.

    ViGEm's get_user_index call returned the same index for different pads,
    so instead each connected XInput slot gets a vibration of a distinct
    strength and we see which of our pads' rumble callbacks receives it.
    Games can't see this (vibration is output only) and the phones are not
    buzzed meanwhile.
    """
    set_state = _xinput_set_state()
    if set_state is None or not callback_states or not connected:
        return {}

    def signature(index):  # 0-255 motor value ViGEm reports for this slot
        return 40 * (index + 1)

    with _probe_lock:
        for state in callback_states.values():
            state["probing"] = True
            state["last_large"] = None
        try:
            for index in connected:
                value = signature(index)
                set_state(index, ctypes.byref(_XInputVibration(value * 257, 0)))
            time.sleep(0.15)
            mapping = {}
            for slot_id, state in callback_states.items():
                received = state.get("last_large")
                if received is None:
                    continue
                for index in connected:
                    if abs(int(received) - signature(index)) <= 3:
                        mapping[slot_id] = index
                        break
            for index in connected:
                set_state(index, ctypes.byref(_XInputVibration(0, 0)))
            time.sleep(0.1)
            return mapping
        finally:
            for state in callback_states.values():
                state["probing"] = False


def vigem_serial(gamepad) -> int | None:
    """ViGEm target index; Windows uses it as the device serial (USB\\...\\08)."""
    try:
        return int(gamepad.get_index())
    except Exception:
        return None


def _is_own_device(device: dict, serials: set[int]) -> bool:
    if device["origin"] != "vigem":
        return False
    instance = device["instanceId"]
    tail = instance.rsplit("\\", 1)[-1].rsplit("&", 1)[-1]
    return tail.isdigit() and int(tail) in serials


def _own_process_ids() -> set[int]:
    me = psutil.Process()
    ids = {me.pid}
    try:
        # In dev the venv's python.exe is a launcher that spawns us.
        ids.update(p.pid for p in me.parents())
    except Exception:
        pass
    return ids


_SERVER_EXE = "manet_network_service.exe"
_PYTHON_EXES = {"python.exe", "pythonw.exe"}


def find_other_servers() -> list[dict]:
    """Other MaNet server processes; they keep their virtual pads plugged in.
    One entry per server: a dev venv launcher and its child count once."""
    own = _own_process_ids()
    servers = {}
    # Only pid+name are cheap to read for every process (ppid, create_time
    # and cmdline cost seconds in total); inspect the candidates only.
    for proc in psutil.process_iter(["pid", "name"]):
        try:
            name = (proc.info["name"] or "").lower()
            if proc.info["pid"] in own or (name != _SERVER_EXE and name not in _PYTHON_EXES):
                continue
            if name in _PYTHON_EXES:
                cmdline = " ".join(proc.cmdline())
                if "src.app.main" not in cmdline or "--probe-" in cmdline:
                    continue
            servers[proc.info["pid"]] = {"ppid": proc.ppid(), "create_time": proc.create_time()}
        except (psutil.NoSuchProcess, psutil.AccessDenied):
            continue
    return [
        {"pid": pid, "startedAt": info["create_time"]}
        for pid, info in servers.items()
        if info["ppid"] not in servers
    ]


def close_other_servers() -> int:
    closed = 0
    for server in find_other_servers():
        try:
            proc = psutil.Process(server["pid"])
            for child in proc.children(recursive=True):
                child.kill()
            proc.kill()
            closed += 1
        except (psutil.NoSuchProcess, psutil.AccessDenied):
            LOG.warning("Could not close stale server pid=%s", server["pid"])
    return closed


def snapshot_own_pads(manager) -> tuple[list[dict], dict[int, dict]]:
    """MaNet's own pads, plus the rumble callback state of each X360 pad
    (used to probe XInput slots). Call on the event loop thread."""
    own_pads = []
    callback_states = {}
    for slot in manager.slots:
        gamepad = getattr(slot, "gamepad", None)
        own_pads.append({
            "slot": slot.slot_id,
            "type": slot.controller_type,
            "playerName": slot.player_name if slot.assigned_device_id else None,
            "serial": vigem_serial(gamepad) if gamepad is not None else None,
            "xinputIndex": None,
        })
        state = getattr(gamepad, "_manet_callback_state", None)
        if slot.controller_type == "x360" and state is not None:
            callback_states[slot.slot_id] = state
    return own_pads, callback_states


def build_inventory(own_pads: list[dict], callback_states: dict[int, dict], controller_mode: str | None) -> dict:
    """Snapshot for the desktop's controllers panel. Safe on a worker thread."""
    connected_list = xinput_connected_indices()
    xinput_of_slot = probe_xinput_indices(callback_states, connected_list)
    for pad in own_pads:
        pad["xinputIndex"] = xinput_of_slot.get(pad["slot"])
    own_by_xinput = {pad["xinputIndex"]: pad for pad in own_pads if pad["xinputIndex"] is not None}
    connected = set(connected_list)
    xinput_slots = []
    for index in range(XINPUT_MAX_USERS):
        pad = own_by_xinput.get(index)
        if pad is not None:
            owner = "manet"
        elif index in connected:
            owner = "other"
        else:
            owner = "free"
        xinput_slots.append({"index": index, "owner": owner, "slot": pad["slot"] if pad else None})

    devices = list_game_controllers()
    serials = {pad["serial"] for pad in own_pads if pad["serial"] is not None}
    for device in devices:
        device["own"] = _is_own_device(device, serials)
    other_servers = find_other_servers()

    return {
        "success": True,
        "controllerMode": controller_mode,
        "ownPads": own_pads,
        "xinputSlots": xinput_slots,
        "devices": devices,
        "summary": {
            "total": len(devices),
            "own": len(own_pads),
            "foreignVirtual": sum(1 for d in devices if d["origin"] == "vigem" and not d["own"]),
            "physical": sum(1 for d in devices if d["origin"] == "physical"),
            "steam": sum(1 for d in devices if d["origin"] == "steam"),
            "playersWithoutXinput": sum(
                1 for pad in own_pads if pad["type"] == "x360" and pad["xinputIndex"] is None
            ),
        },
        "otherServers": other_servers,
    }
