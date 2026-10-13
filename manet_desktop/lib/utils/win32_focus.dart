import 'dart:ffi';
import 'dart:io';

/// Windows only lets the foreground process hand focus to another window.
/// Before MaNet steps aside, it allows any process (the server) to bring the
/// game window to the front.
void allowForegroundHandOff() {
  if (!Platform.isWindows) return;
  try {
    final user32 = DynamicLibrary.open('user32.dll');
    final allow = user32
        .lookupFunction<Int32 Function(Uint32), int Function(int)>(
          'AllowSetForegroundWindow',
        );
    const asfwAny = 0xFFFFFFFF;
    allow(asfwAny);
  } catch (_) {}
}

/// Brings [hwnd] to the front (restoring it if minimized). Only works
/// while MaNet itself is the foreground app; returns whether it took.
bool focusWindow(int hwnd) {
  if (!Platform.isWindows || hwnd == 0) return false;
  try {
    final user32 = DynamicLibrary.open('user32.dll');
    final isWindow = user32
        .lookupFunction<Int32 Function(IntPtr), int Function(int)>('IsWindow');
    final isIconic = user32
        .lookupFunction<Int32 Function(IntPtr), int Function(int)>('IsIconic');
    final showWindow = user32
        .lookupFunction<Int32 Function(IntPtr, Int32), int Function(int, int)>(
          'ShowWindow',
        );
    final setForeground = user32
        .lookupFunction<Int32 Function(IntPtr), int Function(int)>(
          'SetForegroundWindow',
        );
    final getForeground = user32
        .lookupFunction<IntPtr Function(), int Function()>(
          'GetForegroundWindow',
        );
    if (isWindow(hwnd) == 0) return false;
    const swRestore = 9;
    if (isIconic(hwnd) != 0) showWindow(hwnd, swRestore);
    setForeground(hwnd);
    return getForeground() == hwnd;
  } catch (_) {
    return false;
  }
}
