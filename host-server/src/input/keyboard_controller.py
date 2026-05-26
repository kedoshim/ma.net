import ctypes
import logging
import platform
import subprocess
import os
import signal

LOG = logging.getLogger("keyboard_controller")


class KeyboardController:
    VK_VOLUME_MUTE = 0xAD
    VK_VOLUME_DOWN = 0xAE
    VK_VOLUME_UP = 0xAF
    VK_MEDIA_NEXT_TRACK = 0xB0
    VK_MEDIA_PREV_TRACK = 0xB1
    VK_MEDIA_PLAY_PAUSE = 0xB3
    VK_LWIN = 0x5B
    VK_TAB = 0x09
    VK_D = 0x44
    VK_CONTROL = 0x11
    VK_MENU = 0x12
    VK_DELETE = 0x2E
    VK_ESCAPE = 0x1B
    SW_MAXIMIZE = 3
    SW_MINIMIZE = 6
    KEYEVENTF_EXTENDEDKEY = 0x0001
    KEYEVENTF_KEYUP = 0x0002


    def __init__(self):
        self._is_windows = platform.system().lower() == "windows"
        self._user32 = ctypes.windll.user32 if self._is_windows else None

    def _is_process_running(self, process_name: str) -> bool:
        try:
            result = subprocess.run(
                ["tasklist"],
                capture_output=True,
                text=True,
                creationflags=subprocess.CREATE_NO_WINDOW,
            )

            return process_name.lower() in result.stdout.lower()

        except Exception as exc:
            LOG.warning("Failed checking process %s: %s", process_name, exc)
            return False

    def _kill_process(self, process_name: str) -> bool:
        try:
            subprocess.run(
                ["taskkill", "/f", "/im", process_name],
                capture_output=True,
                creationflags=subprocess.CREATE_NO_WINDOW,
            )
            return True

        except Exception as exc:
            LOG.warning("Failed killing process %s: %s", process_name, exc)
            return False

    def perform_action(self, action_id: str) -> None:
        if not self._is_windows or self._user32 is None:
            LOG.warning("Quick action ignored on non-Windows host: %s", action_id)
            return

        LOG.info("Performing quick action: %s", action_id)

        try:
            if action_id == "volume_up":
                self._press(self.VK_VOLUME_UP, extended=True)
            elif action_id == "volume_down":
                self._press(self.VK_VOLUME_DOWN, extended=True)
            elif action_id == "mute_toggle":
                self._press(self.VK_VOLUME_MUTE, extended=True)
            elif action_id == "play_pause":
                self._press(self.VK_MEDIA_PLAY_PAUSE, extended=True)
            elif action_id == "next_track":
                self._press(self.VK_MEDIA_NEXT_TRACK, extended=True)
            elif action_id == "previous_track":
                self._press(self.VK_MEDIA_PREV_TRACK, extended=True)
            elif action_id == "windows_key":
                self._press(self.VK_LWIN, extended=True)
            elif action_id == "windows_tab":
                self._press_combo([
                    (self.VK_LWIN, True),
                    (self.VK_TAB, False),
                ])
            elif action_id == "show_desktop":
                self._press_combo([
                    (self.VK_LWIN, True),
                    (self.VK_D, False),
                ])
            elif action_id == "task_manager":
                self._open_task_manager()
            elif action_id == "escape":
                self._press(self.VK_ESCAPE, extended=True)
            elif action_id == "virtual_keyboard":
                self._open_virtual_keyboard()
            elif action_id == "maximize_window":
                self._show_foreground_window(self.SW_MAXIMIZE)
            elif action_id == "minimize_window":
                self._show_foreground_window(self.SW_MINIMIZE)
            else:
                LOG.warning("Unknown quick action requested: %s", action_id)
        except Exception as exc:
            LOG.exception("Failed to execute quick action %s: %s", action_id, exc)

    def _press(self, vk_code: int, extended: bool = False) -> None:
        flags = self.KEYEVENTF_EXTENDEDKEY if extended else 0
        self._user32.keybd_event(vk_code, 0, flags, 0)
        self._user32.keybd_event(vk_code, 0, flags | self.KEYEVENTF_KEYUP, 0)

    def _press_combo(self, keys):
        for vk, extended in keys:
            self._user32.keybd_event(vk, 0, self.KEYEVENTF_EXTENDEDKEY if extended else 0, 0)
        for vk, extended in reversed(keys):
            self._user32.keybd_event(
                vk,
                0,
                (self.KEYEVENTF_EXTENDEDKEY if extended else 0) | self.KEYEVENTF_KEYUP,
                0,
            )

    def _show_foreground_window(self, mode: int) -> None:
        hwnd = self._user32.GetForegroundWindow()
        if hwnd:
            self._user32.ShowWindow(hwnd, mode)
        else:
            LOG.warning("No foreground window available for quick action.")

    def _lock_workstation(self) -> None:
        try:
            self._user32.LockWorkStation()
        except Exception as exc:
            LOG.warning("Failed fallback lock workstation for Ctrl+Alt+Del: %s", exc)

    def _open_task_manager(self) -> bool:
        try:
            if self._is_process_running("Taskmgr.exe"):
                self._kill_process("Taskmgr.exe")
                return True

            subprocess.Popen(
                ["taskmgr.exe"],
                creationflags=subprocess.CREATE_NO_WINDOW,
            )

            return True

        except Exception as exc:
            LOG.warning("Opening task manager failed: %s", exc)
            return False

    def _open_virtual_keyboard(self) -> None:
        try:
            if self._is_process_running("TabTip.exe"):
                self._kill_process("TabTip.exe")
                return

            keyboard_path = (
                r"C:\Program Files\Common Files\microsoft shared\ink\TabTip.exe"
            )

            os.startfile(keyboard_path)

        except Exception as exc:
            LOG.warning("Could not open virtual keyboard: %s", exc)