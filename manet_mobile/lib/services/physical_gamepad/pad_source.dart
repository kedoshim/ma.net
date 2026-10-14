import 'pad_source_stub.dart'
    if (dart.library.html) 'pad_source_web.dart'
    if (dart.library.io) 'pad_source_io.dart' as impl;

/// A physical gamepad attached to this device (Bluetooth / USB).
class PadInfo {
  final String id;
  final String name;

  const PadInfo(this.id, this.name);
}

/// Full state of one physical pad. Buttons use MaNet's XInput-style ids
/// (A, B, X, Y, LB, RB, LT, RT, LSB, RSB, START, SELECT, HOME, UP, DOWN,
/// LEFT, RIGHT). Sticks are -1..1 with Y up; triggers 0..1.
class PadSnapshot {
  final String id;
  final Set<String> buttons;
  final double lx, ly, rx, ry, lt, rt;

  const PadSnapshot({
    required this.id,
    required this.buttons,
    this.lx = 0,
    this.ly = 0,
    this.rx = 0,
    this.ry = 0,
    this.lt = 0,
    this.rt = 0,
  });
}

/// Platform reader of physical pads: Android (native channel), web (the
/// browser Gamepad API, also used when the controller page is opened on a
/// computer) or nothing.
abstract class PadSource {
  bool get supported;

  /// Connected pads, emitted whenever the list changes.
  Stream<List<PadInfo>> get devices;

  /// Pad states, emitted when something changes.
  Stream<PadSnapshot> get states;

  void start();

  /// While capturing, pad input is not also handled by the app's own UI.
  void setCapture(bool active);

  void rumble(String id, double weak, double strong);
}

PadSource createPadSource() => impl.createPadSource();
