import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';

import 'pad_source.dart';

export 'pad_source.dart' show PadInfo;

/// Relay mode: a physical gamepad attached to this phone (or to the
/// computer whose browser opened the controller page) plays through MaNet as
/// if it were this screen. Its state goes out as the same `stick` / `rstick`
/// / `button` messages the touch controls send, plus analog `trigger`s.
class PhysicalGamepadRelay extends ChangeNotifier {
  static final PhysicalGamepadRelay instance = PhysicalGamepadRelay._();
  PhysicalGamepadRelay._();

  static const double _stickDeadzone = 0.12;
  static const Duration _tick = Duration(milliseconds: 16);
  // The host zeroes a stick it has not heard from in 150ms.
  static const Duration _keepAlive = Duration(milliseconds: 50);

  final PadSource _source = createPadSource();
  bool _started = false;

  List<PadInfo> _pads = const [];
  final Set<String> _offered = {};
  String? _activeId;
  int _captureHolds = 0;

  void Function(Map<String, dynamic> payload)? _sendFn;
  final _presses = StreamController<String>.broadcast();
  final Map<String, Set<String>> _anyPadButtons = {};

  // Latest state of the active pad and what the host was last told.
  PadSnapshot? _latest;
  final Set<String> _sentButtons = {};
  Offset2 _sentLeft = Offset2.zero;
  Offset2 _sentRight = Offset2.zero;
  double _sentLt = 0;
  double _sentRt = 0;
  final Stopwatch _clock = Stopwatch();
  Duration _leftSentAt = Duration.zero;
  Duration _rightSentAt = Duration.zero;
  Timer? _ticker;

  /// When false (a browser on the MaNet PC itself, which also sees MaNet's
  /// virtual pads) new pads are not offered automatically.
  bool autoOffer = true;

  bool get supported => _source.supported;
  List<PadInfo> get pads => _pads;
  String? get activeId => _activeId;
  bool get active => _activeId != null;

  PadInfo? get activePad => _padById(_activeId);

  /// A connected pad this session has not asked about yet.
  PadInfo? get pendingOffer {
    if (!autoOffer || active) return null;
    for (final pad in _pads) {
      if (!_offered.contains(pad.id)) return pad;
    }
    return null;
  }

  /// Buttons pressed on any pad (relaying or not), e.g. to answer the offer.
  Stream<String> get presses => _presses.stream;

  PadInfo? _padById(String? id) {
    if (id == null) return null;
    for (final pad in _pads) {
      if (pad.id == id) return pad;
    }
    return null;
  }

  void start() {
    if (_started || !_source.supported) return;
    _started = true;
    _clock.start();
    _source.devices.listen(_onDevices);
    _source.states.listen(_onState);
    _source.start();
  }

  /// Connected to the host: relayed input starts flowing.
  void attach(void Function(Map<String, dynamic> payload) sendFn) {
    _sendFn = sendFn;
    final latest = _latest;
    if (latest != null) _sendButtons(latest);
    _syncTicker();
  }

  /// Lost the host. The host releases this phone's pad by itself.
  void detach() {
    _sendFn = null;
    _resetSent();
    _syncTicker();
  }

  void markOffered(String id) => _offered.add(id);

  void enable(String id) {
    if (_activeId == id) return;
    _offered.add(id);
    _releaseAll();
    _activeId = id;
    _latest = null;
    _updateCapture();
    _syncTicker();
    notifyListeners();
  }

  void disable() {
    if (_activeId == null) return;
    _releaseAll();
    _activeId = null;
    _latest = null;
    _updateCapture();
    _syncTicker();
    notifyListeners();
  }

  /// Keeps pad input away from the app's UI while a question about the pad
  /// is on screen (the pad answers it with A / B).
  void holdCapture(bool hold) {
    _captureHolds = math.max(0, _captureHolds + (hold ? 1 : -1));
    _updateCapture();
  }

  void _updateCapture() => _source.setCapture(active || _captureHolds > 0);

  void rumble(double weak, double strong) {
    final id = _activeId;
    if (id != null) _source.rumble(id, weak, strong);
  }

  void _onDevices(List<PadInfo> pads) {
    _pads = pads;
    if (_activeId != null && _padById(_activeId) == null) {
      // The relayed pad went away (turned off, out of range).
      _releaseAll();
      _activeId = null;
      _latest = null;
      _updateCapture();
      _syncTicker();
    }
    notifyListeners();
  }

  void _onState(PadSnapshot snapshot) {
    final previous = _anyPadButtons[snapshot.id] ?? const <String>{};
    for (final button in snapshot.buttons.difference(previous)) {
      _presses.add(button);
    }
    _anyPadButtons[snapshot.id] = snapshot.buttons;

    if (snapshot.id != _activeId) return;
    _latest = snapshot;
    _sendButtons(snapshot);
  }

  // --- Sending -----------------------------------------------------------

  void _send(Map<String, dynamic> payload) => _sendFn?.call(payload);

  void _sendButtons(PadSnapshot snapshot) {
    if (_sendFn == null) return;
    // Triggers go out as analog values (also covers pads with digital L2/R2).
    final buttons = snapshot.buttons.difference(const {'LT', 'RT'});

    for (final button in buttons.difference(_sentButtons)) {
      if (button == 'HOME') {
        _send({'type': 'home_pressed'});
      } else {
        _send({'type': 'button', 'id': button, 'state': 'down'});
      }
    }
    for (final button in _sentButtons.difference(buttons)) {
      if (button != 'HOME') _send({'type': 'button', 'id': button, 'state': 'up'});
    }
    _sentButtons
      ..clear()
      ..addAll(buttons);
  }

  void _syncTicker() {
    final run = active && _sendFn != null;
    if (run && _ticker == null) {
      _ticker = Timer.periodic(_tick, (_) => _onTick());
    } else if (!run) {
      _ticker?.cancel();
      _ticker = null;
    }
  }

  void _onTick() {
    final snapshot = _latest;
    if (snapshot == null || _sendFn == null) return;
    final now = _clock.elapsed;

    final left = _deadzone(snapshot.lx, snapshot.ly);
    if (_shouldSendStick(left, _sentLeft, now - _leftSentAt)) {
      _sentLeft = left;
      _leftSentAt = now;
      _send({'type': 'stick', 'x': left.x, 'y': left.y});
    }

    final right = _deadzone(snapshot.rx, snapshot.ry);
    if (_shouldSendStick(right, _sentRight, now - _rightSentAt)) {
      _sentRight = right;
      _rightSentAt = now;
      _send({'type': 'rstick', 'x': right.x, 'y': right.y});
    }

    final lt = _trigger(snapshot.lt, snapshot.buttons.contains('LT'));
    if (lt != _sentLt) {
      _sentLt = lt;
      _send({'type': 'trigger', 'id': 'LT', 'value': lt});
    }
    final rt = _trigger(snapshot.rt, snapshot.buttons.contains('RT'));
    if (rt != _sentRt) {
      _sentRt = rt;
      _send({'type': 'trigger', 'id': 'RT', 'value': rt});
    }
  }

  bool _shouldSendStick(Offset2 value, Offset2 sent, Duration sinceSent) {
    if (value != sent) return true;
    return !value.isZero && sinceSent >= _keepAlive;
  }

  /// Radial deadzone, rescaled so the stick still reaches full deflection;
  /// rounded so sensor noise doesn't flood the socket.
  static Offset2 _deadzone(double x, double y) {
    final magnitude = math.sqrt(x * x + y * y);
    if (magnitude < _stickDeadzone) return Offset2.zero;
    final scaled = math.min(1.0, (magnitude - _stickDeadzone) / (1 - _stickDeadzone));
    double round(double v) => (v * 100).roundToDouble() / 100;
    return Offset2(
      round((x / magnitude * scaled).clamp(-1.0, 1.0)),
      round((y / magnitude * scaled).clamp(-1.0, 1.0)),
    );
  }

  static double _trigger(double analog, bool digital) {
    final value = math.max(analog, digital ? 1.0 : 0.0);
    if (value < 0.04) return 0;
    return (value * 50).roundToDouble() / 50;
  }

  /// Lets go of everything the host thinks this pad is holding.
  void _releaseAll() {
    if (_sendFn != null) {
      for (final button in _sentButtons) {
        if (button != 'HOME') _send({'type': 'button', 'id': button, 'state': 'up'});
      }
      if (!_sentLeft.isZero) _send({'type': 'stick', 'x': 0.0, 'y': 0.0});
      if (!_sentRight.isZero) _send({'type': 'rstick', 'x': 0.0, 'y': 0.0});
      if (_sentLt != 0) _send({'type': 'trigger', 'id': 'LT', 'value': 0.0});
      if (_sentRt != 0) _send({'type': 'trigger', 'id': 'RT', 'value': 0.0});
    }
    _resetSent();
  }

  void _resetSent() {
    _sentButtons.clear();
    _sentLeft = Offset2.zero;
    _sentRight = Offset2.zero;
    _sentLt = 0;
    _sentRt = 0;
  }
}

@immutable
class Offset2 {
  final double x;
  final double y;

  const Offset2(this.x, this.y);

  static const zero = Offset2(0, 0);

  bool get isZero => x == 0 && y == 0;

  @override
  bool operator ==(Object other) => other is Offset2 && other.x == x && other.y == y;

  @override
  int get hashCode => Object.hash(x, y);
}
