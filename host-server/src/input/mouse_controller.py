import ctypes
import math
import platform


class MouseController:
    _MOUSEEVENTF_MOVE = 0x0001
    _MOUSEEVENTF_LEFTDOWN = 0x0002
    _MOUSEEVENTF_LEFTUP = 0x0004
    _MOUSEEVENTF_RIGHTDOWN = 0x0008
    _MOUSEEVENTF_RIGHTUP = 0x0010
    _MOUSEEVENTF_WHEEL = 0x0800
    _WHEEL_DELTA = 120

    def __init__(self):
        self._is_windows = platform.system().lower() == "windows"
        self._user32 = ctypes.windll.user32 if self._is_windows else None
        self._base_speed = 12.0
        self._max_speed = 23.0

    def move(self, x, y):
        if not self._is_windows:
            return

        dx = self._scaled_delta(x)
        dy = self._scaled_delta(y)
        if dx == 0 and dy == 0:
            return

        self._user32.mouse_event(self._MOUSEEVENTF_MOVE, dx, dy, 0, 0)

    def left_down(self):
        self._mouse_event(self._MOUSEEVENTF_LEFTDOWN)

    def left_up(self):
        self._mouse_event(self._MOUSEEVENTF_LEFTUP)

    def right_down(self):
        self._mouse_event(self._MOUSEEVENTF_RIGHTDOWN)

    def right_up(self):
        self._mouse_event(self._MOUSEEVENTF_RIGHTUP)

    def scroll(self, delta):
        if not self._is_windows:
            return

        amount = int(round(delta * self._WHEEL_DELTA))
        if amount == 0:
            return

        self._user32.mouse_event(self._MOUSEEVENTF_WHEEL, 0, 0, amount, 0)

    def _mouse_event(self, flag):
        if not self._is_windows:
            return

        self._user32.mouse_event(flag, 0, 0, 0, 0)

    def _scaled_delta(self, value):
        amount = float(value or 0)
        if abs(amount) < 0.03:
            return 0

        magnitude = min(1.0, abs(amount))
        curved = math.pow(magnitude, 1.85)
        pixels = self._base_speed + (self._max_speed - self._base_speed) * curved
        return int(round(math.copysign(pixels * magnitude, amount)))
