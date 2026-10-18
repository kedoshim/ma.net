import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:manet_desktop/models/player_face.dart';
import 'package:manet_desktop/models/session_models.dart';
import 'package:manet_desktop/screens/home_page/console_lobby_view.dart';
import 'package:manet_desktop/screens/home_page/gamepad_state.dart';
import 'package:manet_desktop/screens/library/face_playground.dart';
import 'package:manet_desktop/services/host_api_service.dart';
import 'package:manet_desktop/services/session_controller.dart';
import 'package:manet_desktop/widgets/player_face_indicator.dart';
import 'package:provider/provider.dart';

class _FakePads extends GamepadState {
  _FakePads() : super(HostApiService(host: '127.0.0.1', port: 1));

  final StreamController<PadButtonEvent> events = StreamController.broadcast();

  @override
  Stream<PadButtonEvent> get buttonEvents => events.stream;
}

class _FakeSession extends SessionController {
  _FakeSession() : super(HostApiService(host: '127.0.0.1', port: 1));

  final List<(String, bool)> zoneCalls = [];

  void show(SessionSnapshot next) {
    snapshot = next;
    notifyListeners();
  }

  @override
  Future<void> setLobbyZone(String deviceId, bool inside) async {
    zoneCalls.add((deviceId, inside));
  }
}

DeviceModel _device(String id, Color color) => DeviceModel(
  id: id,
  name: id,
  connected: true,
  color: color,
  face: PlayerFaceData(color: color, faceText: ':)', rotation: PlayerFaceRotation.normal),
);

SessionSnapshot _snapshot({
  required List<String> players,
  required List<String> queue,
  Set<String> zone = const {},
}) => SessionSnapshot(
  consoleMode: true,
  players: [
    for (var i = 0; i < players.length; i++)
      SessionPlayer(deviceId: players[i], slot: i, ready: queue.contains(players[i])),
  ],
  queue: queue,
  playZone: zone,
);

void main() {
  late _FakePads pads;
  late _FakeSession session;

  Future<void> pumpLobby(
    WidgetTester tester,
    SessionSnapshot snapshot,
    List<String> ids, {
    ConnectionInfo? connection,
    String? hotspotName,
    Widget Function(double size)? hotspotCard,
  }) async {
    tester.view.physicalSize = const Size(1600, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    pads = _FakePads();
    pads.slots = [
      for (var i = 0; i < ids.length; i++)
        SlotModel(slot: i, device: _device(ids[i], Colors.primaries[i])),
    ];
    session = _FakeSession()..snapshot = snapshot;
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider<GamepadState>.value(value: pads),
          ChangeNotifierProvider<SessionController>.value(value: session),
        ],
        child: MaterialApp(
          home: Scaffold(
            body: ConsoleLobbyView(
              qrCard: (_) => const ColoredBox(color: Colors.white),
              connection: connection,
              hotspotName: hotspotName,
              hotspotCard: hotspotCard,
            ),
          ),
        ),
      ),
    );
  }

  Future<void> run(WidgetTester tester, Duration duration) async {
    for (var i = 0; i < duration.inMilliseconds ~/ 16; i++) {
      await tester.pump(const Duration(milliseconds: 16));
    }
  }

  testWidgets('forming shapes, falling faces and ready pills', (tester) async {
    final ids = ['a', 'b', 'c', 'd'];
    await pumpLobby(
      tester,
      _snapshot(players: ids, queue: ['b', 'c', 'd'], zone: {'d'}),
      ids,
    );
    await run(tester, const Duration(milliseconds: 500));
    expect(tester.takeException(), isNull);

    // a is still making their face, b and c roll around, d is a pill.
    expect(find.text('editando rostinho...'), findsOneWidget);
    expect(find.byIcon(Icons.arrow_forward_rounded), findsOneWidget);
    expect(find.byType(FacePlayground), findsOneWidget);

    // a checks in: the shape turns into a circle, then drops.
    session.show(_snapshot(players: ids, queue: ['b', 'c', 'd', 'a'], zone: {'d'}));
    await run(tester, const Duration(milliseconds: 900));
    expect(tester.takeException(), isNull);
    expect(find.text('editando rostinho...'), findsNothing);
    // b, c, a in the playground + d's pill.
    expect(find.byType(PlayerFaceIndicator), findsNWidgets(4));

    // d cancels: the pill goes, d rolls back in from the right.
    session.show(_snapshot(players: ids, queue: ['b', 'c', 'd', 'a']));
    await run(tester, const Duration(milliseconds: 300));
    expect(find.byIcon(Icons.arrow_forward_rounded), findsNothing);
    expect(find.byType(PlayerFaceIndicator), findsNWidgets(4));
    expect(tester.takeException(), isNull);
  });

  testWidgets('a face rolling out through the right edge reports ready', (tester) async {
    final ids = ['a'];
    await pumpLobby(tester, _snapshot(players: ids, queue: ['a']), ids);
    // Rolling back in from the right after a cancel is the easiest way to
    // get a fast face near the edge: push it right with the stick.
    final notifier = pads.inputListenable('a') as ValueNotifier<DeviceInputState>;
    notifier.value = notifier.value.copyWith(stickX: 1);
    await run(tester, const Duration(seconds: 4));
    expect(session.zoneCalls, contains(('a', true)));
    expect(tester.takeException(), isNull);
  });

  testWidgets('forming shapes keep their spot when someone leaves', (tester) async {
    final ids = ['a', 'b', 'c'];
    await pumpLobby(tester, _snapshot(players: ids, queue: const []), ids);
    await run(tester, const Duration(milliseconds: 300));
    final b = tester.getCenter(find.text('b'));
    final c = tester.getCenter(find.text('c'));

    // 'a' leaves: the others stay where they were (only the gentle bob).
    session.show(_snapshot(players: ['b', 'c'], queue: const []));
    await run(tester, const Duration(milliseconds: 300));
    expect((tester.getCenter(find.text('b')) - b).distance, lessThan(16));
    expect((tester.getCenter(find.text('c')) - c).distance, lessThan(16));
  });

  testWidgets('cancelling back to editing takes the closest spot sideways', (tester) async {
    final ids = ['a'];
    await pumpLobby(tester, _snapshot(players: ids, queue: ['a']), ids);
    // Roll to the far left, then cancel back to editing.
    final notifier = pads.inputListenable('a') as ValueNotifier<DeviceInputState>;
    notifier.value = notifier.value.copyWith(stickX: -1);
    await run(tester, const Duration(seconds: 3));
    notifier.value = notifier.value.copyWith(stickX: 0);
    final ballX = tester.getCenter(find.byType(PlayerFaceIndicator)).dx;
    expect(ballX, lessThan(300));

    session.show(_snapshot(players: ids, queue: const []));
    await run(tester, const Duration(milliseconds: 300));
    final blobX = tester.getCenter(find.text('a')).dx;
    // The leftmost column of spots (8% of 1600 px, give or take jitter).
    expect(blobX, lessThan(220));
    expect(tester.takeException(), isNull);
  });

  testWidgets('join steps offer the Wi-Fi and the hotspot, with the card above', (tester) async {
    final wifi = ConnectionInfo(
      id: 'wifi',
      url: 'http://192.168.0.20:8080',
      wsUrl: 'ws://192.168.0.20:8080/ws',
      ip: '192.168.0.20',
      displayNameKey: 'connection_label_wifi__CasaNet',
      kind: 'wifi',
      recommended: true,
      selected: true,
      preferred: false,
      lastSuccessful: false,
    );
    await pumpLobby(
      tester,
      _snapshot(players: const [], queue: const []),
      const [],
      connection: wifi,
      hotspotName: 'MANET-PC',
      hotspotCard: (size) => SizedBox(key: const ValueKey('hotspot-card'), width: size, height: size),
    );
    await run(tester, const Duration(milliseconds: 100));
    expect(tester.takeException(), isNull);

    final step = find.textContaining('MANET-PC', findRichText: true);
    expect(step, findsOneWidget);
    expect(find.textContaining('CasaNet', findRichText: true), findsOneWidget);
    final card = find.byKey(const ValueKey('hotspot-card'));
    expect(card, findsOneWidget);
    expect(tester.getRect(card).bottom, lessThan(tester.getRect(step).top));
  });
}
