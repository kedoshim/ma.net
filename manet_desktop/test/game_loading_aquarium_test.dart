import 'dart:async';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:manet_desktop/l10n/app_localizations.dart';
import 'package:manet_desktop/models/player_face.dart';
import 'package:manet_desktop/models/session_models.dart';
import 'package:manet_desktop/screens/home_page/gamepad_state.dart';
import 'package:manet_desktop/screens/library/game_loading_view.dart';
import 'package:manet_desktop/services/host_api_service.dart';
import 'package:manet_desktop/services/session_controller.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _FakePads extends GamepadState {
  _FakePads() : super(HostApiService(host: '127.0.0.1', port: 1));

  final StreamController<PadButtonEvent> events = StreamController.broadcast();

  @override
  Stream<PadButtonEvent> get buttonEvents => events.stream;
}

const _players = [
  ('a', 'Ana', Colors.orange, ':)'),
  ('b', 'Beto', Colors.lightBlue, ':D'),
  ('c', 'Cris', Colors.pink, 'X)'),
];

void main() {
  setUpAll(() async {
    for (final font in [
      ('momo', 'assets/fonts/Momo_Trust_Display/MomoTrustDisplay-Regular.ttf'),
      ('monomaniac', 'assets/fonts/Monomaniac_One/MonomaniacOne-Regular.ttf'),
      ('MaterialIcons', 'fonts/MaterialIcons-Regular.otf'),
    ]) {
      await (FontLoader(font.$1)..addFont(rootBundle.load(font.$2))).load();
    }
  });

  testWidgets('every press throws a face in the box and the counter goes up', (tester) async {
    SharedPreferences.setMockInitialValues({'aquarium_record_kart': 25, 'aquarium_record_other': 500});
    tester.view.physicalSize = const Size(1280, 720);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    final api = HostApiService(host: '127.0.0.1', port: 1);
    final session = SessionController(api)
      ..games = const [GameEntry(id: 'kart', name: 'Kart Rápido', path: 'k')]
      ..snapshot = SessionSnapshot(
        phase: SessionPhase.inGame,
        players: [
          for (var i = 0; i < _players.length; i++)
            SessionPlayer(deviceId: _players[i].$1, slot: i, ready: true),
        ],
        runningGame: const RunningGameInfo(id: 'kart', name: 'Kart Rápido', tracked: true),
        gameReady: false,
        launchStartedAt: DateTime.now(),
      );
    final pads = _FakePads()
      ..slots = [
        for (var i = 0; i < _players.length; i++)
          SlotModel(
            slot: i,
            device: DeviceModel(
              id: _players[i].$1,
              name: _players[i].$2,
              connected: true,
              color: _players[i].$3,
              face: PlayerFaceData(
                color: _players[i].$3,
                faceText: _players[i].$4,
                rotation: PlayerFaceRotation.normal,
              ),
            ),
          ),
      ];
    final key = GlobalKey();
    await tester.pumpWidget(
      AppLocalizations(
        notifier: LocaleNotifier(),
        child: MultiProvider(
          providers: [
            ChangeNotifierProvider<SessionController>.value(value: session),
            ChangeNotifierProvider<GamepadState>.value(value: pads),
          ],
          child: MaterialApp(
            debugShowCheckedModeBanner: false,
            home: RepaintBoundary(
              key: key,
              child: const Scaffold(
                backgroundColor: Color(0xFFE6F2FF),
                body: Padding(padding: EdgeInsets.all(24), child: GameLoadingView()),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 100));
    final strings = tester.element(find.byType(GameLoadingView)).l10n.session;
    expect(find.text('0'), findsNWidgets(4)); // total and each player
    expect(find.text(strings.aquariumHint), findsOneWidget);

    // Three players mashing for a few seconds; START does not throw.
    for (var i = 0; i < 90; i++) {
      final id = _players[i % 3].$1;
      pads.events
        ..add(PadButtonEvent(id, 'A', true))
        ..add(PadButtonEvent(id, 'A', false));
      if (i % 3 == 0) pads.events.add(PadButtonEvent(id, 'START', true));
      await tester.pump(const Duration(milliseconds: 40));
    }
    await tester.pump(const Duration(milliseconds: 600));
    expect(find.text('90'), findsOneWidget);
    // Each player's count, in the ranking under the total.
    expect(find.text('30'), findsNWidgets(3));
    expect(find.text(strings.aquariumNewRecord), findsOneWidget);

    final boundary = key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
    await tester.runAsync(() async {
      final image = await boundary.toImage(pixelRatio: 0.8);
      final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
      Directory('build/shots').createSync(recursive: true);
      File('build/shots/game_loading_aquarium.png').writeAsBytesSync(bytes!.buffer.asUint8List());
    });

    // The record is kept for the next loading screen.
    await tester.pump(const Duration(seconds: 2));
    await tester.runAsync(() async {
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getInt('aquarium_record_kart'), 90);
      expect(prefs.getInt('aquarium_record_other'), 500);
    });
    await tester.pumpWidget(const SizedBox());
  });
}
