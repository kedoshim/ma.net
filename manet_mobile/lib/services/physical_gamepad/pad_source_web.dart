// ignore_for_file: deprecated_member_use, avoid_web_libraries_in_flutter
import 'dart:async';
import 'dart:html' as html;
import 'dart:js_util' as js_util;

import 'pad_source.dart';

/// Browser Gamepad API, on phones and computers alike. Browsers only expose
/// a pad after one of its buttons is pressed while the page is open.
class WebPadSource implements PadSource {
  // "Standard" mapping button indices -> MaNet ids.
  static const _buttonNames = [
    'A', 'B', 'X', 'Y', 'LB', 'RB', 'LT', 'RT', 'SELECT', 'START',
    'LSB', 'RSB', 'UP', 'DOWN', 'LEFT', 'RIGHT', 'HOME',
  ];
  static const _pollInterval = Duration(milliseconds: 16);

  final _devices = StreamController<List<PadInfo>>.broadcast();
  final _states = StreamController<PadSnapshot>.broadcast();
  final Map<String, html.Gamepad> _pads = {};
  final Map<String, String> _lastSignature = {};
  Timer? _timer;

  @override
  bool get supported => true;

  @override
  Stream<List<PadInfo>> get devices => _devices.stream;

  @override
  Stream<PadSnapshot> get states => _states.stream;

  @override
  void start() {
    _timer ??= Timer.periodic(_pollInterval, (_) => _poll());
  }

  void _poll() {
    List<html.Gamepad?> list;
    try {
      list = html.window.navigator.getGamepads();
    } catch (_) {
      return;
    }

    final current = <String, html.Gamepad>{};
    for (final pad in list) {
      if (pad == null || pad.connected == false) continue;
      current['${pad.index}'] = pad;
    }

    final changed = current.length != _pads.length ||
        current.keys.any((id) => _pads[id]?.id != current[id]!.id);
    _pads
      ..clear()
      ..addAll(current);
    if (changed) {
      _lastSignature.removeWhere((id, _) => !current.containsKey(id));
      _devices.add([
        for (final entry in current.entries) PadInfo(entry.key, _cleanName(entry.value.id)),
      ]);
    }

    for (final entry in current.entries) {
      final snapshot = _snapshot(entry.key, entry.value);
      final signature = '${snapshot.buttons.join(',')}|${snapshot.lx},${snapshot.ly},'
          '${snapshot.rx},${snapshot.ry},${snapshot.lt},${snapshot.rt}';
      if (_lastSignature[entry.key] == signature) continue;
      _lastSignature[entry.key] = signature;
      _states.add(snapshot);
    }
  }

  PadSnapshot _snapshot(String id, html.Gamepad pad) {
    final buttons = pad.buttons ?? const [];
    final axes = pad.axes ?? const [];
    final pressed = <String>{};
    for (var i = 0; i < buttons.length && i < _buttonNames.length; i++) {
      if (buttons[i].pressed == true) pressed.add(_buttonNames[i]);
    }
    double axis(int i) => i < axes.length ? axes[i].toDouble() : 0;
    double trigger(int i) => i < buttons.length ? (buttons[i].value ?? 0).toDouble() : 0;
    return PadSnapshot(
      id: id,
      buttons: pressed,
      lx: axis(0),
      ly: -axis(1),
      rx: axis(2),
      ry: -axis(3),
      lt: trigger(6),
      rt: trigger(7),
    );
  }

  /// "Xbox Wireless Controller (STANDARD GAMEPAD Vendor: 045e ...)" -> the name.
  static String _cleanName(String? raw) {
    var name = (raw ?? '').trim();
    final paren = name.indexOf(' (');
    if (paren > 0) name = name.substring(0, paren);
    // Firefox: "045e-0b13-Xbox Wireless Controller".
    name = name.replaceFirst(RegExp(r'^[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-'), '');
    return name.isEmpty ? 'Gamepad' : name;
  }

  @override
  void setCapture(bool active) {
    // The app's UI never reads the Gamepad API, nothing to suppress.
  }

  @override
  void rumble(String id, double weak, double strong) {
    final pad = _pads[id];
    if (pad == null) return;
    try {
      final actuator = js_util.getProperty<Object?>(pad, 'vibrationActuator');
      if (actuator == null) return;
      if (weak <= 0 && strong <= 0) {
        if (js_util.hasProperty(actuator, 'reset')) js_util.callMethod(actuator, 'reset', const []);
        return;
      }
      // Held until the next rumble update (the server sends a stop).
      js_util.callMethod(actuator, 'playEffect', [
        'dual-rumble',
        js_util.jsify({
          'duration': 2000,
          'weakMagnitude': weak.clamp(0.0, 1.0),
          'strongMagnitude': strong.clamp(0.0, 1.0),
        }),
      ]);
    } catch (_) {}
  }
}

PadSource createPadSource() => WebPadSource();
