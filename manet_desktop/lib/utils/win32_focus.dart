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

/// Minimizes MaNet's own window without activating anything else. A plain
/// minimize (SC_MINIMIZE) activates the next window in line, taking the
/// focus back from the game MaNet just handed it to; full screen games like
/// Nidhogg then minimize themselves and leave the desktop on the TV.
/// Returns false when the window can't be found (the caller falls back).
bool minimizeWithoutActivating() {
  if (!Platform.isWindows) return false;
  try {
    final user32 = DynamicLibrary.open('user32.dll');
    final kernel32 = DynamicLibrary.open('kernel32.dll');
    final findWindowEx = user32.lookupFunction<
      IntPtr Function(IntPtr, IntPtr, Pointer<Uint16>, Pointer<Uint16>),
      int Function(int, int, Pointer<Uint16>, Pointer<Uint16>)
    >('FindWindowExW');
    final windowProcess = user32.lookupFunction<
      Uint32 Function(IntPtr, Pointer<Uint32>),
      int Function(int, Pointer<Uint32>)
    >('GetWindowThreadProcessId');
    final showWindow = user32
        .lookupFunction<Int32 Function(IntPtr, Int32), int Function(int, int)>(
          'ShowWindow',
        );
    final currentProcess = kernel32
        .lookupFunction<Uint32 Function(), int Function()>(
          'GetCurrentProcessId',
        );
    final heap = kernel32.lookupFunction<IntPtr Function(), int Function()>(
      'GetProcessHeap',
    );
    final heapAlloc = kernel32.lookupFunction<
      Pointer Function(IntPtr, Uint32, IntPtr),
      Pointer Function(int, int, int)
    >('HeapAlloc');
    final heapFree = kernel32.lookupFunction<
      Int32 Function(IntPtr, Uint32, Pointer),
      int Function(int, int, Pointer)
    >('HeapFree');

    const className = 'FLUTTER_RUNNER_WIN32_WINDOW';
    final heapHandle = heap();
    final name = heapAlloc(heapHandle, 8, (className.length + 1) * 2)
        .cast<Uint16>();
    final pid = heapAlloc(heapHandle, 8, 4).cast<Uint32>();
    try {
      for (var i = 0; i < className.length; i++) {
        name[i] = className.codeUnitAt(i);
      }
      final me = currentProcess();
      var hwnd = 0;
      while (true) {
        hwnd = findWindowEx(0, hwnd, name, nullptr);
        if (hwnd == 0) return false;
        windowProcess(hwnd, pid);
        if (pid.value == me) break;
      }
      const swShowMinNoActive = 7;
      showWindow(hwnd, swShowMinNoActive);
      return true;
    } finally {
      heapFree(heapHandle, 0, name.cast());
      heapFree(heapHandle, 0, pid.cast());
    }
  } catch (_) {
    return false;
  }
}
