// Dev tool: drives the lobby -> library -> game flow against a running dev
// server with fake phones and writes screenshots to build/session_shots.
//   1. MANET_GAMES_FILE=<tmp>/games.json python -m src.app.main --port 8880 --slots 0
//   2. MANET_TEST_PORT=8880 flutter test tool/session_screens_test.dart
import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:manet_desktop/l10n/app_localizations.dart';
import 'package:manet_desktop/screens/home_page/home_page_widget.dart';
import 'package:shared_preferences/shared_preferences.dart';

Future<void> _loadFont(String family, ByteData data) async {
  final loader = FontLoader(family)..addFont(Future.value(data));
  await loader.load();
}

class FakePhone {
  final WebSocket socket;
  FakePhone(this.socket) {
    socket.listen((_) {}); // keep reading so heartbeat pings get answered
  }

  static Future<FakePhone> connect(int port, String id, String name) async =>
      FakePhone(await WebSocket.connect('ws://127.0.0.1:$port/ws?deviceId=$id&name=$name'));

  void press(String button) {
    socket.add(jsonEncode({'type': 'button', 'id': button, 'state': 'down'}));
    socket.add(jsonEncode({'type': 'button', 'id': button, 'state': 'up'}));
  }

  void stick(double x, double y) => socket.add(jsonEncode({'type': 'stick', 'x': x, 'y': y}));
}

void main() {
  final port = int.parse(Platform.environment['MANET_TEST_PORT'] ?? '8880');
  final outDir = Platform.environment['MANET_SHOT_DIR'] ?? 'build/session_shots';
  final base = 'http://127.0.0.1:$port';

  setUpAll(() async {
    HttpOverrides.global = null;
    SharedPreferences.setMockInitialValues({'has_seen_onboarding': true});
    await _loadFont('momo', await rootBundle.load('assets/fonts/Momo_Trust_Display/MomoTrustDisplay-Regular.ttf'));
    await _loadFont('MaterialIcons', await rootBundle.load('fonts/MaterialIcons-Regular.otf'));
    final segoe = ByteData.sublistView(File(r'C:\Windows\Fonts\segoeui.ttf').readAsBytesSync());
    for (final family in ['momo_sans', 'Roboto', 'Segoe UI']) {
      await _loadFont(family, segoe);
    }
    Directory(outDir).createSync(recursive: true);
  });

  testWidgets('session flow screens', (tester) async {
    tester.view.physicalSize = const Size(1280, 720);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final client = HttpClient();
    Future<Map<String, dynamic>> post(String path, Map<String, dynamic> body) async {
      final request = await client.postUrl(Uri.parse('$base$path'));
      request.headers.contentType = ContentType.json;
      request.write(jsonEncode(body));
      final response = await request.close();
      return jsonDecode(await response.transform(utf8.decoder).join()) as Map<String, dynamic>;
    }

    Future<void> settle([int ms = 600]) async {
      for (var i = 0; i < ms ~/ 100; i++) {
        await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 100)));
        await tester.pump(const Duration(milliseconds: 100));
      }
    }

    final key = GlobalKey();
    Future<void> shot(String name) async {
      final boundary = key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
      await tester.runAsync(() async {
        final image = await boundary.toImage(pixelRatio: 0.6);
        final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
        File('$outDir/$name.png').writeAsBytesSync(bytes!.buffer.asUint8List());
      });
      // ignore: avoid_print
      print('SHOT $name');
    }

    late List<FakePhone> phones;
    late Map<String, dynamic> kart, party, solo;
    await tester.runAsync(() async {
      // Start from a clean server: lobby phase, empty library.
      await post('/api/session/return', {});
      final listing = await client.getUrl(Uri.parse('$base/api/games'));
      final existing = jsonDecode(await (await listing.close()).transform(utf8.decoder).join());
      for (final game in existing['games'] as List) {
        final request = await client.deleteUrl(Uri.parse('$base/api/games/${game['id']}'));
        await (await request.close()).drain<void>();
      }
      await post('/api/server/reset-controllers', {'mode': 'ds4', 'slots': 3, 'fixed': true});
      phones = [
        await FakePhone.connect(port, 'fake1', 'Ana'),
        await FakePhone.connect(port, 'fake2', 'Bruno'),
        await FakePhone.connect(port, 'fake3', 'Carla'),
      ];
      final icon = File('assets/icon/icon.png').absolute.path;
      kart = (await post('/api/games', {
        'name': 'Kart Rápido', 'path': Platform.resolvedExecutable, 'coverPath': icon,
        'minPlayers': 1, 'maxPlayers': 4,
      }))['game'];
      party = (await post('/api/games', {
        'name': 'Party Ilha', 'path': Platform.resolvedExecutable, 'minPlayers': 2, 'maxPlayers': 8,
      }))['game'];
      solo = (await post('/api/games', {
        'name': 'Aventura Solo', 'path': Platform.resolvedExecutable, 'minPlayers': 1, 'maxPlayers': 1,
      }))['game'];
    });

    await tester.pumpWidget(
      AppLocalizations(
        notifier: LocaleNotifier(),
        child: RepaintBoundary(
          key: key,
          child: MaterialApp(
            debugShowCheckedModeBanner: false,
            home: HomePageScreen(host: '127.0.0.1', port: port, initialControllerMode: 'ds4'),
          ),
        ),
      ),
    );
    await settle(2500);

    // Phase 2: lobby in menu mode, two of three players ready.
    await tester.runAsync(() => post('/api/session/focus', {'focused': true}));
    await settle();
    await shot('1_lobby_waiting');
    phones[0].press('START');
    phones[1].press('START');
    await settle();
    await shot('2_lobby_two_ready');
    phones[2].press('START');
    await settle();
    await shot('3_lobby_all_ready');

    // Phase 3: START with everyone ready opens the library.
    phones[0].press('START');
    await settle(1200);
    await shot('4_library');

    // Ana steers right and up for a moment, then votes with A.
    phones[0].stick(0.9, 0.0);
    await settle(400);
    phones[0].stick(0.0, 0.9);
    await settle(400);
    phones[0].stick(0, 0);
    await settle(300);
    await shot('5_library_cursor_moved');
    phones[0].press('A');
    await settle();

    // Bruno and Carla vote through the API (same as an A press on a card).
    await tester.runAsync(() async {
      await post('/api/session/vote', {'deviceId': 'fake2', 'gameId': party['id']});
    });
    await settle();
    await shot('6_library_votes');
    await tester.runAsync(() async {
      await post('/api/session/vote', {'deviceId': 'fake3', 'gameId': party['id']});
    });
    await settle(1000);
    await shot('7_countdown');
    await tester.runAsync(() => post('/api/session/cancel-countdown', {}));
    await settle();
    final denied = await tester.runAsync(
      () => post('/api/session/vote', {'deviceId': 'fake1', 'gameId': solo['id']}),
    );
    // ignore: avoid_print
    print('VOTE for 1-player game with 3 players accepted: ${denied?['success']}');

    // Manage games dialog.
    await tester.tap(find.byIcon(Icons.edit_rounded).first);
    await settle(1000);
    await shot('8_manage_games');
    await tester.tap(find.byIcon(Icons.edit_rounded).last);
    await settle(1000);
    await shot('9_edit_game');

    // Scroll the editor down to the rules / screen / full screen section.
    await tester.ensureVisible(find.text('x•input up to 4, d•input above'));
    await settle(300);
    await tester.tap(find.text('x•input up to 4, d•input above'));
    await settle(300);
    await tester.ensureVisible(find.text('Open full screen'));
    await settle(600);
    await shot('10_edit_game_rules');

    // Layout creator from the "+" next to a layout dropdown.
    await tester.tap(find.byIcon(Icons.add_rounded).first);
    await settle(1200);
    await shot('11_layout_creator');
    await tester.tap(find.byIcon(Icons.arrow_back_ios_new_rounded).first);
    await settle(800);

    // Cover search hits the real Steam store.
    await tester.enterText(find.byType(TextField).at(1), 'Overcooked');
    await settle(200);
    await Scrollable.ensureVisible(tester.element(find.text('Find cover')), alignment: 0.5);
    await settle(200);
    await tester.tap(find.text('Find cover'));
    for (var i = 0; i < 8; i++) {
      await settle(1000);
    }
    await shot('12_cover_search');
    Navigator.of(tester.element(find.text('Find a cover'))).pop();
    await settle(600);
    Navigator.of(tester.element(find.text('Edit game'))).pop();
    await settle(600);
    Navigator.of(tester.element(find.text('Games'))).pop();
    await settle(600);
    await shot('13_library_cards');

    // Leave the lobby like the power button does; must not throw.
    Navigator.of(tester.element(find.byType(HomePageScreen))).pushReplacement(
      MaterialPageRoute<void>(builder: (_) => const SizedBox()),
    );
    await settle(1000);
    // ignore: avoid_print
    print('LEAVE: ${tester.takeException() ?? 'clean'}');
    for (final phone in phones) {
      unawaited(phone.socket.close());
    }
    await tester.runAsync(() async {
      for (final game in [kart, party, solo]) {
        final request = await client.deleteUrl(Uri.parse('$base/api/games/${game['id']}'));
        await (await request.close()).drain<void>();
      }
    });
    await tester.pumpWidget(const SizedBox());
    await settle(300);
    // Let request timeouts started by the screens expire in fake time.
    await tester.pump(const Duration(seconds: 30));
    client.close(force: true);
  }, timeout: const Timeout(Duration(minutes: 3)));
}
