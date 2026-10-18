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
import 'package:manet_desktop/screens/library/game_overlay.dart';
import 'package:manet_desktop/services/host_api_service.dart';
import 'package:manet_desktop/services/session_controller.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

DeviceModel _device(String id, String name, Color color) => DeviceModel(
  id: id,
  name: name,
  connected: true,
  color: color,
  face: PlayerFaceData(
    color: color,
    faceText: ':)',
    rotation: PlayerFaceRotation.normal,
  ),
);

Future<void> _pump(
  WidgetTester tester,
  GlobalKey key, {
  required List<SessionPlayer> players,
  required AwayState? away,
}) async {
  final api = HostApiService(host: '127.0.0.1', port: 1);
  final session = SessionController(api)
    ..snapshot = SessionSnapshot(
      phase: SessionPhase.inGame,
      players: players,
      runningGame: const RunningGameInfo(id: 'kart', name: 'Kart Rápido', tracked: true),
      overlayOpen: true,
      away: away,
    );
  final pads = GamepadState(api)
    ..slots = [
      SlotModel(
        slot: 0,
        device: players.isEmpty ? null : _device('a', 'Ana', Colors.orange),
      ),
      SlotModel(slot: 1, device: null),
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
          home: RepaintBoundary(key: key, child: const GameOverlay()),
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
    SharedPreferences.setMockInitialValues({});
    for (final font in [
      ('momo', 'assets/fonts/Momo_Trust_Display/MomoTrustDisplay-Regular.ttf'),
      ('MaterialIcons', 'fonts/MaterialIcons-Regular.otf'),
    ]) {
      await (FontLoader(font.$1)..addFont(rootBundle.load(font.$2))).load();
    }
  });

  testWidgets('overlay: away (QR, close timer, then resume/switch) and normal', (tester) async {
    tester.view.physicalSize = const Size(1280, 720);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final key = GlobalKey();

    await _pump(
      tester,
      key,
      players: const [],
      away: AwayState(closeAt: DateTime.now().add(const Duration(minutes: 29, seconds: 30))),
    );
    final strings = tester.element(find.byType(GameOverlay)).l10n.session;
    expect(find.text(strings.awayTitle), findsOneWidget);
    expect(find.text(strings.awayScan), findsOneWidget);
    expect(find.textContaining('29:'), findsOneWidget);
    expect(find.text(strings.overlayResume), findsNothing);
    await _shot(tester, key, 'overlay_away_empty');

    await _pump(
      tester,
      key,
      players: const [SessionPlayer(deviceId: 'a', slot: 0, ready: false)],
      away: const AwayState(),
    );
    expect(find.text(strings.awayChooseTitle), findsOneWidget);
    expect(find.text(strings.awayResume), findsOneWidget);
    expect(find.text(strings.awaySwitch), findsOneWidget);
    expect(find.text(strings.awayWaits), findsOneWidget);
    expect(find.text(strings.overlayLayout), findsNothing);
    await _shot(tester, key, 'overlay_away_choice');

    await _pump(
      tester,
      key,
      players: const [SessionPlayer(deviceId: 'a', slot: 0, ready: false)],
      away: null,
    );
    expect(find.text(strings.overlayResume), findsOneWidget);
    expect(find.text(strings.overlayLayout), findsOneWidget);
    expect(find.text(strings.awayTitle), findsNothing);
    await _shot(tester, key, 'overlay_normal');

    // Up from the first entry focuses the QR card; A (Enter) shows it huge.
    const giant = ValueKey('giant-qr');
    expect(find.byKey(giant), findsNothing);
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowUp);
    await tester.pump(const Duration(milliseconds: 300));
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.byKey(giant), findsOneWidget);
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 200)));
    await tester.pump();
    await _shot(tester, key, 'overlay_qr_giant');
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.byKey(giant), findsNothing);
    expect(find.text(strings.overlayResume), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
  });
}
