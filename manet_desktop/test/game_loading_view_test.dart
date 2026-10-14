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

Future<void> _pump(WidgetTester tester, Duration sinceLaunch, GlobalKey key) async {
  final api = HostApiService(host: '127.0.0.1', port: 1);
  final session = SessionController(api)
    ..games = const [GameEntry(id: 'kart', name: 'Kart Rápido', path: 'k')]
    ..snapshot = SessionSnapshot(
      phase: SessionPhase.inGame,
      players: const [SessionPlayer(deviceId: 'a', slot: 0, ready: true)],
      runningGame: const RunningGameInfo(id: 'kart', name: 'Kart Rápido', tracked: true),
      gameReady: false,
      launchStartedAt: DateTime.now().subtract(sinceLaunch),
    );
  final pads = GamepadState(api)
    ..slots = [
      SlotModel(
        slot: 0,
        device: DeviceModel(
          id: 'a',
          name: 'Ana',
          connected: true,
          color: Colors.orange,
          face: const PlayerFaceData(
            color: Colors.orange,
            faceText: ':)',
            rotation: PlayerFaceRotation.normal,
          ),
        ),
      ),
    ];
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
  await tester.pump(const Duration(milliseconds: 600));
}

Future<void> _shot(WidgetTester tester, GlobalKey key, String name) async {
  final boundary = key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
  await tester.runAsync(() async {
    final image = await boundary.toImage(pixelRatio: 0.6);
    final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
    Directory('build/shots').createSync(recursive: true);
    File('build/shots/$name.png').writeAsBytesSync(bytes!.buffer.asUint8List());
  });
}

void main() {
  setUpAll(() async {
    for (final font in [
      ('momo', 'assets/fonts/Momo_Trust_Display/MomoTrustDisplay-Regular.ttf'),
      ('MaterialIcons', 'fonts/MaterialIcons-Regular.otf'),
    ]) {
      await (FontLoader(font.$1)..addFont(rootBundle.load(font.$2))).load();
    }
  });

  testWidgets('loading screen names the game; the way out only when slow', (tester) async {
    tester.view.physicalSize = const Size(1280, 720);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final key = GlobalKey();

    await _pump(tester, const Duration(seconds: 3), key);
    final strings = tester.element(find.byType(GameLoadingView)).l10n.session;
    expect(find.text(strings.loadingGame('Kart Rápido')), findsOneWidget);
    expect(find.text(strings.loadingShowGame), findsNothing);
    await _shot(tester, key, 'game_loading');

    await _pump(tester, const Duration(seconds: 20), key);
    expect(find.text(strings.loadingShowGame), findsOneWidget);
    await _shot(tester, key, 'game_loading_slow');
    await tester.pumpWidget(const SizedBox());
  });
}
