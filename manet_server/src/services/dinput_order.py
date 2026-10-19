"""
The order games see DInput pads in, so seats can follow it.

DirectInput (and most games numbering "DualShock 0, 1, 2...") list pads in
the order Windows keeps their HID interfaces, which is a fixed shuffle of
the device instance IDs, not the order the pads were plugged in. ViGEm
derives the instance ID from the pad's serial, so the order is a stable
function of the serials: we read it and hand pads to seats in that order.
"""
import ctypes
import logging
import sys
import uuid
from ctypes import wintypes

from src.services.controller_inventory import _origin

LOG = logging.getLogger(__name__)

_DI8DEVCLASS_GAMECTRL = 4
_DIEDFL_ATTACHEDONLY = 1
_DIPROP_GUIDANDPATH = 12
_IID_IDIRECTINPUT8W = "BF798031-483A-4DA2-AA99-5D64ED369700"


class _GUID(ctypes.Structure):
    _fields_ = [
        ("Data1", wintypes.DWORD),
        ("Data2", wintypes.WORD),
        ("Data3", wintypes.WORD),
        ("Data4", ctypes.c_ubyte * 8),
    ]

    @classmethod
    def parse(cls, text):
        guid = cls()
        ctypes.memmove(ctypes.byref(guid), uuid.UUID(text).bytes_le, 16)
        return guid


class _DIDEVICEINSTANCEW(ctypes.Structure):
    _fields_ = [
        ("dwSize", wintypes.DWORD),
        ("guidInstance", _GUID),
        ("guidProduct", _GUID),
        ("dwDevType", wintypes.DWORD),
        ("tszInstanceName", wintypes.WCHAR * 260),
        ("tszProductName", wintypes.WCHAR * 260),
        ("guidFFDriver", _GUID),
        ("wUsagePage", wintypes.WORD),
        ("wUsage", wintypes.WORD),
    ]


class _DIPROPHEADER(ctypes.Structure):
    _fields_ = [
        ("dwSize", wintypes.DWORD),
        ("dwHeaderSize", wintypes.DWORD),
        ("dwObj", wintypes.DWORD),
        ("dwHow", wintypes.DWORD),
    ]


class _DIPROPGUIDANDPATH(ctypes.Structure):
    _fields_ = [("diph", _DIPROPHEADER), ("guidClass", _GUID), ("wszPath", wintypes.WCHAR * 260)]


_HRESULT = ctypes.c_long
_ENUM_CALLBACK = ctypes.WINFUNCTYPE(wintypes.BOOL, ctypes.POINTER(_DIDEVICEINSTANCEW), ctypes.c_void_p)


def _method(obj, index, restype, *argtypes):
    vtable = ctypes.cast(obj, ctypes.POINTER(ctypes.POINTER(ctypes.c_void_p))).contents
    return ctypes.WINFUNCTYPE(restype, ctypes.c_void_p, *argtypes)(vtable[index])


def _release(obj):
    _method(obj, 2, ctypes.c_ulong)(obj)


def _parent_serial(cfg, hid_path: str) -> int | None:
    r"""ViGEm serial of a pad from its HID path (\\?\hid#vid_...#2&hash&1&0000#{guid}):
    the parent USB node's instance ID ends in the serial (...\1&79F5D87&1&08)."""
    parts = hid_path[4:].split("#")[:3]
    if len(parts) < 3:
        return None
    devinst = wintypes.DWORD()
    if cfg.CM_Locate_DevNodeW(ctypes.byref(devinst), "\\".join(parts).upper(), 0) != 0:
        return None
    parent = wintypes.DWORD()
    if cfg.CM_Get_Parent(ctypes.byref(parent), devinst, 0) != 0:
        return None
    if _origin(parent.value) != "vigem":
        return None  # a real pad's instance ID can end in a number too
    buf = ctypes.create_unicode_buffer(512)
    if cfg.CM_Get_Device_IDW(parent, buf, 512, 0) != 0:
        return None
    tail = buf.value.rsplit("&", 1)[-1]
    return int(tail) if tail.isdigit() else None


def dinput_serial_order() -> list[int]:
    """ViGEm serials of the attached game controllers, in DirectInput order.
    Pads that are not ViGEm's are skipped. Empty when DirectInput is missing."""
    if sys.platform != "win32":
        return []
    try:
        dinput = ctypes.WinDLL("dinput8")
        cfg = ctypes.WinDLL("cfgmgr32")
        kernel32 = ctypes.WinDLL("kernel32")
    except OSError:
        return []
    kernel32.GetModuleHandleW.restype = ctypes.c_void_p
    di = ctypes.c_void_p()
    hr = dinput.DirectInput8Create(
        ctypes.c_void_p(kernel32.GetModuleHandleW(None)),
        0x0800,
        ctypes.byref(_GUID.parse(_IID_IDIRECTINPUT8W)),
        ctypes.byref(di),
        None,
    )
    if hr != 0 or not di:
        LOG.warning("DirectInput8Create failed: 0x%08X", hr & 0xFFFFFFFF)
        return []

    try:
        instances = []

        def collect(instance, _ref):
            instances.append(_DIDEVICEINSTANCEW.from_buffer_copy(instance.contents))
            return 1

        callback = _ENUM_CALLBACK(collect)
        _method(di, 4, _HRESULT, wintypes.DWORD, _ENUM_CALLBACK, ctypes.c_void_p, wintypes.DWORD)(
            di, _DI8DEVCLASS_GAMECTRL, callback, None, _DIEDFL_ATTACHEDONLY
        )

        create_device = _method(di, 3, _HRESULT, ctypes.POINTER(_GUID), ctypes.POINTER(ctypes.c_void_p), ctypes.c_void_p)
        serials = []
        for instance in instances:
            device = ctypes.c_void_p()
            if create_device(di, ctypes.byref(instance.guidInstance), ctypes.byref(device), None) != 0 or not device:
                continue
            try:
                prop = _DIPROPGUIDANDPATH()
                prop.diph = _DIPROPHEADER(ctypes.sizeof(_DIPROPGUIDANDPATH), ctypes.sizeof(_DIPROPHEADER), 0, 0)
                if _method(device, 5, _HRESULT, ctypes.c_void_p, ctypes.c_void_p)(device, _DIPROP_GUIDANDPATH, ctypes.byref(prop)) != 0:
                    continue
                serial = _parent_serial(cfg, prop.wszPath)
                if serial is not None:
                    serials.append(serial)
            finally:
                _release(device)
        return serials
    finally:
        _release(di)
