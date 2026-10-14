import 'dart:async';
import 'dart:io';

import 'package:flutter/services.dart';

import 'pad_source.dart';
import 'pad_source_stub.dart';

/// Android: MainActivity reads the pads (Flutter only gets their buttons as
/// key events, never the sticks) and streams them over a channel.
class AndroidPadSource implements PadSource {
  static const _methods = MethodChannel('manet/gamepad');
  static const _events = EventChannel('manet/gamepad/events');

  final _devices = StreamController<List<PadInfo>>.broadcast();
  final _states = StreamController<PadSnapshot>.broadcast();
  StreamSubscription? _subscription;

  @override
  bool get supported => true;

  @override
  Stream<List<PadInfo>> get devices => _devices.stream;

  @override
  Stream<PadSnapshot> get states => _states.stream;

  @override
  void start() {
    _subscription ??= _events.receiveBroadcastStream().listen(_onEvent, onError: (_) {});
  }

  void _onEvent(dynamic event) {
    if (event is! Map) return;
    switch (event['event']) {
      case 'devices':
        final pads = (event['pads'] as List? ?? const [])
            .whereType<Map>()
            .map((p) => PadInfo('${p['id']}', '${p['name']}'))
            .toList();
        _devices.add(pads);
      case 'state':
        double axis(String key) => (event[key] as num?)?.toDouble() ?? 0;
        _states.add(PadSnapshot(
          id: '${event['id']}',
          buttons: (event['buttons'] as List? ?? const []).map((b) => '$b').toSet(),
          lx: axis('lx'),
          ly: axis('ly'),
          rx: axis('rx'),
          ry: axis('ry'),
          lt: axis('lt'),
          rt: axis('rt'),
        ));
    }
  }

  @override
  void setCapture(bool active) {
    unawaited(_methods.invokeMethod('setCapture', {'active': active}).catchError((_) => null));
  }

  @override
  void rumble(String id, double weak, double strong) {
    final deviceId = int.tryParse(id);
    if (deviceId == null) return;
    unawaited(_methods
        .invokeMethod('rumble', {'id': deviceId, 'weak': weak, 'strong': strong})
        .catchError((_) => null));
  }
}

PadSource createPadSource() => Platform.isAndroid ? AndroidPadSource() : UnsupportedPadSource();
