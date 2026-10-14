"""
Puts a launched game's window on the chosen monitor and, if asked, makes a
windowed game cover that monitor without borders (what "borderless
fullscreen" tools do). Games already in exclusive/borderless fullscreen on
the right monitor are left alone.
"""
import asyncio
import ctypes
import logging
import sys
from ctypes import wintypes

LOG = logging.getLogger(__name__)

PLACEMENT_TIMEOUT_SECONDS = 25.0
# Games often recreate or resize their window while loading; keep enforcing
# the placement for a while after it first sticks.
SETTLE_SECONDS = 6.0
POLL_SECONDS = 0.5

GWL_STYLE = -16
GWL_EXSTYLE = -20
GW_OWNER = 4
WS_CAPTION = 0x00C00000
WS_THICKFRAME = 0x00040000
WS_MINIMIZEBOX = 0x00020000
WS_MAXIMIZEBOX = 0x00010000
WS_SYSMENU = 0x00080000
WS_EX_DLGMODALFRAME = 0x00000001
WS_EX_CLIENTEDGE = 0x00000200
WS_EX_STATICEDGE = 0x00020000
SWP_FRAMECHANGED = 0x0020
SWP_SHOWWINDOW = 0x0040
SWP_NOZORDER = 0x0004
MONITORINFOF_PRIMARY = 0x1
MONITOR_DEFAULTTONEAREST = 2

if sys.platform == "win32":
    user32 = ctypes.WinDLL("user32", use_last_error=True)
    _LONG_PTR = ctypes.c_ssize_t
    user32.GetWindowLongPtrW.restype = _LONG_PTR
    user32.GetWindowLongPtrW.argtypes = [wintypes.HWND, ctypes.c_int]
    user32.SetWindowLongPtrW.restype = _LONG_PTR
    user32.SetWindowLongPtrW.argtypes = [wintypes.HWND, ctypes.c_int, _LONG_PTR]
    user32.GetWindowThreadProcessId.argtypes = [wintypes.HWND, ctypes.POINTER(wintypes.DWORD)]
    user32.GetWindow.restype = wintypes.HWND
    user32.GetWindow.argtypes = [wintypes.HWND, wintypes.UINT]
    user32.GetForegroundWindow.restype = wintypes.HWND
    user32.SetForegroundWindow.argtypes = [wintypes.HWND]
    user32.ShowWindow.argtypes = [wintypes.HWND, ctypes.c_int]
    user32.IsIconic.argtypes = [wintypes.HWND]
    user32.MonitorFromWindow.restype = wintypes.HMONITOR
    user32.MonitorFromWindow.argtypes = [wintypes.HWND, wintypes.DWORD]
    user32.SetWindowPos.argtypes = [
        wintypes.HWND, wintypes.HWND, ctypes.c_int, ctypes.c_int, ctypes.c_int, ctypes.c_int, wintypes.UINT,
    ]
    user32.IsWindow.argtypes = [wintypes.HWND]
    user32.BringWindowToTop.argtypes = [wintypes.HWND]
    user32.AttachThreadInput.argtypes = [wintypes.DWORD, wintypes.DWORD, wintypes.BOOL]
    user32.keybd_event.argtypes = [wintypes.BYTE, wintypes.BYTE, wintypes.DWORD, ctypes.c_size_t]
    kernel32 = ctypes.WinDLL("kernel32", use_last_error=True)
else:  # pragma: no cover - the server only runs on Windows
    user32 = None


def enable_dpi_awareness():
    """Use real pixels: without this, Windows scales the coordinates this
    process sees (1920x1080 at 125% reads as 1536x864) and game windows end
    up misplaced. Call once at startup."""
    if user32 is None:
        return
    try:
        # DPI_AWARENESS_CONTEXT_PER_MONITOR_AWARE_V2
        user32.SetProcessDpiAwarenessContext(ctypes.c_void_p(-4))
    except Exception:
        LOG.debug("Could not enable per-monitor DPI awareness", exc_info=True)


class _MonitorInfoEx(ctypes.Structure):
    _fields_ = [
        ("cbSize", wintypes.DWORD),
        ("rcMonitor", wintypes.RECT),
        ("rcWork", wintypes.RECT),
        ("dwFlags", wintypes.DWORD),
        ("szDevice", wintypes.WCHAR * 32),
    ]


def _monitor_info(hmonitor):
    info = _MonitorInfoEx()
    info.cbSize = ctypes.sizeof(_MonitorInfoEx)
    if not user32.GetMonitorInfoW(hmonitor, ctypes.byref(info)):
        return None
    r = info.rcMonitor
    return {
        "device": info.szDevice,
        "primary": bool(info.dwFlags & MONITORINFOF_PRIMARY),
        "x": r.left,
        "y": r.top,
        "width": r.right - r.left,
        "height": r.bottom - r.top,
    }


def list_displays() -> list[dict]:
    """Monitors, primary first then left to right; `index` is what games store."""
    if user32 is None:
        return []
    monitors = []
    proc = ctypes.WINFUNCTYPE(
        wintypes.BOOL, wintypes.HMONITOR, wintypes.HDC, ctypes.POINTER(wintypes.RECT), wintypes.LPARAM,
    )

    def collect(hmonitor, _hdc, _rect, _data):
        info = _monitor_info(hmonitor)
        if info:
            monitors.append(info)
        return True

    user32.EnumDisplayMonitors(None, None, proc(collect), 0)
    monitors.sort(key=lambda m: (not m["primary"], m["x"], m["y"]))
    for index, monitor in enumerate(monitors):
        monitor["index"] = index
    return monitors


class _WINDOWPLACEMENT(ctypes.Structure):
    _fields_ = [
        ("length", wintypes.UINT),
        ("flags", wintypes.UINT),
        ("showCmd", wintypes.UINT),
        ("ptMinPosition", wintypes.POINT),
        ("ptMaxPosition", wintypes.POINT),
        ("rcNormalPosition", wintypes.RECT),
    ]


def _window_rect(hwnd):
    """Window rectangle; for a minimized window, where it will be restored
    (full screen games often minimize themselves when they lose focus)."""
    rect = wintypes.RECT()
    if user32.IsIconic(hwnd):
        placement = _WINDOWPLACEMENT()
        placement.length = ctypes.sizeof(_WINDOWPLACEMENT)
        if user32.GetWindowPlacement(hwnd, ctypes.byref(placement)):
            rect = placement.rcNormalPosition
    else:
        user32.GetWindowRect(hwnd, ctypes.byref(rect))
    return rect.left, rect.top, rect.right - rect.left, rect.bottom - rect.top


def visible_windows() -> dict:
    """hwnd -> pid of every visible, unowned, window-sized top-level window."""
    found = {}
    if user32 is None:
        return found
    proc = ctypes.WINFUNCTYPE(wintypes.BOOL, wintypes.HWND, wintypes.LPARAM)

    def visit(hwnd, _):
        if not user32.IsWindowVisible(hwnd) or user32.GetWindow(hwnd, GW_OWNER):
            return True
        _, _, w, h = _window_rect(hwnd)
        if w >= 200 and h >= 150:
            pid = wintypes.DWORD()
            user32.GetWindowThreadProcessId(hwnd, ctypes.byref(pid))
            found[hwnd] = pid.value
        return True

    user32.EnumWindows(proc(visit), 0)
    return found


def find_main_window(pids: set[int]):
    """Largest visible top-level window owned by any of `pids`."""
    best, best_area = None, 0
    proc = ctypes.WINFUNCTYPE(wintypes.BOOL, wintypes.HWND, wintypes.LPARAM)

    def visit(hwnd, _):
        if not user32.IsWindowVisible(hwnd) or user32.GetWindow(hwnd, GW_OWNER):
            return True
        pid = wintypes.DWORD()
        user32.GetWindowThreadProcessId(hwnd, ctypes.byref(pid))
        if pid.value not in pids:
            return True
        _, _, w, h = _window_rect(hwnd)
        nonlocal best, best_area
        if w >= 200 and h >= 150 and w * h > best_area:
            best, best_area = hwnd, w * h
        return True

    user32.EnumWindows(proc(visit), 0)
    return best


def place_window(hwnd, display: dict | None, fullscreen: bool) -> bool:
    """Returns True when the window already is where it should be."""
    current_monitor = _monitor_info(user32.MonitorFromWindow(hwnd, MONITOR_DEFAULTTONEAREST))
    target = display or current_monitor
    if target is None:
        return True
    x, y, w, h = _window_rect(hwnd)
    target_rect = (target["x"], target["y"], target["width"], target["height"])

    if fullscreen:
        if (x, y, w, h) == target_rect:
            return True
        style = user32.GetWindowLongPtrW(hwnd, GWL_STYLE)
        user32.SetWindowLongPtrW(
            hwnd, GWL_STYLE, style & ~(WS_CAPTION | WS_THICKFRAME | WS_MINIMIZEBOX | WS_MAXIMIZEBOX | WS_SYSMENU),
        )
        ex_style = user32.GetWindowLongPtrW(hwnd, GWL_EXSTYLE)
        user32.SetWindowLongPtrW(
            hwnd, GWL_EXSTYLE, ex_style & ~(WS_EX_DLGMODALFRAME | WS_EX_CLIENTEDGE | WS_EX_STATICEDGE),
        )
        user32.SetWindowPos(hwnd, None, *target_rect, SWP_FRAMECHANGED | SWP_SHOWWINDOW | SWP_NOZORDER)
        LOG.info("Made game window borderless full screen on %s", target["device"])
        return False

    if display is None or (current_monitor and current_monitor["device"] == display["device"]):
        return True
    # Keep the size; center it on the chosen monitor.
    new_x = display["x"] + max(0, (display["width"] - w) // 2)
    new_y = display["y"] + max(0, (display["height"] - h) // 2)
    user32.SetWindowPos(hwnd, None, new_x, new_y, w, h, SWP_SHOWWINDOW | SWP_NOZORDER)
    LOG.info("Moved game window to %s", display["device"])
    return False


async def enforce_placement(running, display_index: int | None, fullscreen: bool):
    """Background task started after a tracked launch."""
    if user32 is None or (display_index is None and not fullscreen):
        return
    displays = list_displays()
    display = next((d for d in displays if d["index"] == display_index), None)
    loop = asyncio.get_running_loop()
    deadline = loop.time() + PLACEMENT_TIMEOUT_SECONDS
    placed_at = None
    while loop.time() < deadline:
        await asyncio.sleep(POLL_SECONDS)
        pids = await asyncio.to_thread(running.alive_pids)
        if not pids:
            return
        hwnd = await asyncio.to_thread(find_main_window, pids)
        if hwnd is None:
            continue
        in_place = await asyncio.to_thread(place_window, hwnd, display, fullscreen)
        if in_place:
            placed_at = placed_at or loop.time()
            if loop.time() - placed_at >= SETTLE_SECONDS:
                return
        else:
            placed_at = None


def move_to_monitor(pid: int, monitor: dict) -> bool:
    """Move a process's main window onto `monitor` (centered, same size),
    so the desktop can then go full screen there."""
    if user32 is None or not pid or not monitor:
        return False
    hwnd = find_main_window({pid})
    if not hwnd:
        return False
    current = _monitor_info(user32.MonitorFromWindow(hwnd, MONITOR_DEFAULTTONEAREST))
    if current and current["device"] == monitor["device"]:
        return True
    _, _, w, h = _window_rect(hwnd)
    w, h = min(w, monitor["width"]), min(h, monitor["height"])
    x = monitor["x"] + (monitor["width"] - w) // 2
    y = monitor["y"] + (monitor["height"] - h) // 2
    return bool(user32.SetWindowPos(hwnd, None, x, y, w, h, SWP_SHOWWINDOW | SWP_NOZORDER))


def capture_game_screen(monitor: dict | None) -> bytes | None:
    """JPEG of `monitor` (or the main one), small enough to send to the
    desktop as the overlay's backdrop."""
    from io import BytesIO
    from PIL import ImageGrab

    bbox = None
    if monitor:
        bbox = (
            monitor["x"], monitor["y"],
            monitor["x"] + monitor["width"], monitor["y"] + monitor["height"],
        )
    image = ImageGrab.grab(bbox=bbox, all_screens=True)
    image.thumbnail((1280, 1280))
    buffer = BytesIO()
    image.convert("RGB").save(buffer, format="JPEG", quality=70)
    return buffer.getvalue()


SW_RESTORE = 9
VK_MENU = 0x12
KEYEVENTF_KEYUP = 0x0002


def foreground_window() -> tuple[int | None, int | None]:
    """(hwnd, pid) of the window in front."""
    if user32 is None:
        return None, None
    hwnd = user32.GetForegroundWindow()
    if not hwnd:
        return None, None
    pid = wintypes.DWORD()
    user32.GetWindowThreadProcessId(hwnd, ctypes.byref(pid))
    return hwnd, pid.value or None


def is_window(hwnd) -> bool:
    return bool(user32 is not None and hwnd and user32.IsWindow(hwnd))


def window_monitor(hwnd) -> dict | None:
    """Monitor of `hwnd` (a minimized window counts where it was)."""
    if not is_window(hwnd):
        return None
    return _monitor_info(user32.MonitorFromWindow(hwnd, MONITOR_DEFAULTTONEAREST))


def focus_window(hwnd) -> bool:
    """Bring `hwnd` to the front, restoring it if minimized. Windows only
    lets the foreground process do this freely, so when the plain call is
    refused it uses the usual workarounds: a synthetic ALT tap (unlocks
    SetForegroundWindow) and attaching to the foreground thread's input."""
    if not is_window(hwnd):
        return False
    if user32.IsIconic(hwnd):
        user32.ShowWindow(hwnd, SW_RESTORE)
    if user32.SetForegroundWindow(hwnd) and user32.GetForegroundWindow() == hwnd:
        return True

    user32.keybd_event(VK_MENU, 0, 0, 0)
    user32.keybd_event(VK_MENU, 0, KEYEVENTF_KEYUP, 0)
    if user32.SetForegroundWindow(hwnd) and user32.GetForegroundWindow() == hwnd:
        return True

    front = user32.GetForegroundWindow()
    front_thread = user32.GetWindowThreadProcessId(front, None) if front else 0
    own_thread = kernel32.GetCurrentThreadId()
    attached = bool(front_thread) and front_thread != own_thread and bool(
        user32.AttachThreadInput(own_thread, front_thread, True)
    )
    try:
        user32.BringWindowToTop(hwnd)
        user32.SetForegroundWindow(hwnd)
    finally:
        if attached:
            user32.AttachThreadInput(own_thread, front_thread, False)
    return user32.GetForegroundWindow() == hwnd


def describe_window(hwnd) -> str:
    """'process.exe "title"' for logs."""
    if not is_window(hwnd):
        return "?"
    pid = wintypes.DWORD()
    user32.GetWindowThreadProcessId(hwnd, ctypes.byref(pid))
    try:
        import psutil
        name = psutil.Process(pid.value).name()
    except Exception:
        name = f"pid {pid.value}"
    title = ctypes.create_unicode_buffer(120)
    user32.GetWindowTextW(hwnd, title, 120)
    return f'{name} "{title.value}"'
