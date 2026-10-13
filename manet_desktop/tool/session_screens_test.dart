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
        'description': 'Corridas malucas com itens, atalhos e muita casca de banana pelo caminho.',
        'tags': ['Corrida', 'Tela dividida'],
        'trailerUrl': 'https://www.youtube.com/watch?v=tKlRN2YpxRE',
        'minPlayers': 1, 'maxPlayers': 4,
      }))['game'];
      party = (await post('/api/games', {
        'name': 'Party Ilha', 'path': Platform.resolvedExecutable, 'minPlayers': 2, 'maxPlayers': 8,
        'description': 'Minigames rápidos numa ilha: quem juntar mais estrelas vence.',
        'tags': ['Festa', 'Co-op'],
      }))['game'];
      solo = (await post('/api/games', {
        'name': 'Aventura Solo', 'path': Platform.resolvedExecutable, 'minPlayers': 1, 'maxPlayers': 1,
        'tags': ['Aventura'],
      }))['game'];
      // Enough games to fill the strip and scroll it sideways.
      for (var i = 1; i <= 30; i++) {
        await post('/api/games', {
          'name': 'Jogo Extra $i', 'path': Platform.resolvedExecutable,
          if (i.isEven) 'coverPath': icon,
          'minPlayers': 1, 'maxPlayers': 4, 'tags': [if (i % 3 == 0) 'Luta' else 'Festa'],
        });
      }
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

    // Phase 3: everyone ready counts down 5 s, then the library opens.
    await settle(1200);
    await shot('3b_lobby_countdown');
    phones[1].press('Y');
    await settle(300);
    await shot('3c_lobby_emote');
    await settle(4500);
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
      await post('/api/session/vote', {'deviceId': 'fake1', 'gameId': party['id']});
      await post('/api/session/vote', {'deviceId': 'fake2', 'gameId': party['id']});
    });
    await settle();
    await shot('6_library_votes');
    // Carla reads a game's details on her phone, then pushes the strip right.
    await tester.runAsync(
      () => post('/api/session/details', {'deviceId': 'fake3', 'gameId': kart['id']}),
    );
    await settle();
    await shot('6b_library_reading');
    await tester.runAsync(
      () => post('/api/session/details', {'deviceId': 'fake3', 'gameId': null}),
    );
    phones[2].stick(1, 0);
    await settle(3000);
    await shot('6c_library_pushed');
    // Ana takes her vote back and pushes the other way while Carla keeps
    // pushing: the strip stays still.
    await tester.runAsync(
      () => post('/api/session/vote', {'deviceId': 'fake1', 'gameId': null}),
    );
    await settle(300);
    phones[0].stick(-1, 0);
    await settle(2500);
    await shot('6d_library_tug_of_war');
    phones[0].stick(0, 0);
    phones[2].stick(0, 0);
    await settle(300);
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

    // Three different picks -> elimination tournament.
    Future<String?> stage() async {
      final request = await client.getUrl(Uri.parse('$base/api/session'));
      final body = jsonDecode(await (await request.close()).transform(utf8.decoder).join());
      final session = (body['session'] ?? body) as Map<String, dynamic>;
      return (session['tournament'] as Map<String, dynamic>?)?['stage'] as String?;
    }

    Future<void> waitStage(String wanted, {int maxMs = 12000}) async {
      for (var waited = 0; waited < maxMs; waited += 200) {
        if (await tester.runAsync(stage) == wanted) return;
        await settle(200);
      }
      // ignore: avoid_print
      print('TOURNAMENT stage $wanted not reached');
    }

    await tester.runAsync(() async {
      final race = (await post('/api/games', {
        'name': 'Corrida Maluca', 'path': Platform.resolvedExecutable, 'minPlayers': 1, 'maxPlayers': 4,
        'tags': ['Corrida'],
      }))['game'];
      await post('/api/session/settings', {'matchSeconds': 5});
      await post('/api/session/vote', {'deviceId': 'fake3', 'gameId': null});
      await post('/api/session/vote', {'deviceId': 'fake1', 'gameId': kart['id']});
      await post('/api/session/vote', {'deviceId': 'fake3', 'gameId': race['id']});
    });
    await settle(1200);
    await shot('7b_tournament_intro');
    await waitStage('match');
    await settle(300);
    // Ana walks to the left field, Bruno to the right; Carla stays in the
    // middle (no vote) for the shot, then joins Ana.
    phones[0].stick(-0.9, 0);
    phones[1].stick(0.9, 0);
    await settle(500);
    phones[0].stick(0, 0);
    phones[1].stick(0, 0);
    await settle(500);
    await shot('7c_tournament_match');
    phones[2].stick(-0.9, 0.3);
    await settle(400);
    phones[2].stick(0, 0);
    await waitStage('result');
    await settle(700);
    await shot('7d_tournament_result');
    await waitStage('champion', maxMs: 16000);
    await settle(900);
    await shot('7e_tournament_champion');
    await tester.runAsync(() async {
      await post('/api/session/cancel-tournament', {});
      for (final id in ['fake1', 'fake2', 'fake3']) {
        await post('/api/session/vote', {'deviceId': id, 'gameId': null});
      }
    });
    await settle();

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

    // Filters, sorting and the details panel.
    await tester.tap(find.text('Corrida').first);
    await tester.tap(find.text('A–Z'));
    await settle(500);
    await shot('13b_library_filtered');
    await tester.tap(find.text('Clear'));
    await settle(300);
    await tester.tap(find.byIcon(Icons.info_outline_rounded).first);
    await settle(1500);
    await shot('13c_library_details');
    await tester.tap(find.text('Close'));
    await settle(500);

    // Phase 4: a running game and the in-game overlay.
    late Map<String, dynamic> sleeper;
    await tester.runAsync(() async {
      sleeper = (await post('/api/games', {
        'name': 'Sleeper',
        'path': Platform.environment['MANET_SLEEPER_EXE'] ?? r'C:\Python313\python.exe',
        'arguments': '-c "import time; time.sleep(120)"',
        'minPlayers': 1,
        'maxPlayers': 4,
        'fullscreen': false,
      }))['game'];
      await post('/api/session/play', {'gameId': sleeper['id']});
    });
    await settle(4500);
    await shot('14_in_game');
    // Only the player who opened the overlay (phones[0]) can drive it.
    void press(String button) => phones[0].press(button);
    phones[0].socket.add(jsonEncode({'type': 'home_pressed'}));
    await settle(2500);
    await shot('15_overlay');
    // The others play in the face playground meanwhile (and can't move the
    // owner's menu): Bruno rolls right and jumps, Carla jumps.
    phones[1].stick(0.9, 0);
    await settle(700);
    phones[1].press('A');
    await settle(100);
    await shot('15b_overlay_playground');
    phones[1].stick(0, 0);
    await settle(1500);
    await shot('15c_overlay_playground_rest');
    press('DOWN');
    await settle(400);
    press('A');
    await settle(1500);
    await shot('16_overlay_add_players');
    press('B');
    await settle(300);
    press('DOWN');
    await settle(300);
    press('A');
    await settle(800);
    await shot('17_overlay_layouts');
    press('B');
    await settle(300);
    press('DOWN');
    press('DOWN');
    await settle(300);
    press('A');
    await settle(600);
    await shot('18_overlay_confirm_close');
    press('A');
    await settle(1500);
    await shot('19_after_close_game');
    await tester.runAsync(() async {
      final request = await client.deleteUrl(Uri.parse('$base/api/games/${sleeper['id']}'));
      await (await request.close()).drain<void>();
    });

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
