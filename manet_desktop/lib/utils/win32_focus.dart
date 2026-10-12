import 'dart:ffi';
import 'dart:io';

/// Windows only lets the foreground process hand focus to another window.
/// Before MaNet steps aside, it allows any process (the server) to bring the
/// game window to the front.
void allowForegroundHandOff() {
  if (!Platform.isWindows) return;
  try {
    final user32 = DynamicLibrary.open('user32.dll');
    final allow = user32.lookupFunction<Int32 Function(Uint32), int Function(int)>(
      'AllowSetForegroundWindow',
    );
    const asfwAny = 0xFFFFFFFF;
    allow(asfwAny);
  } catch (_) {}
}
