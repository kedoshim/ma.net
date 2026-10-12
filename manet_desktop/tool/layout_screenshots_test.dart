// Dev tool: renders the real lobby against a running dev server at several
// window sizes, reports overflows and writes PNG screenshots to
// build/layout_shots. Lives outside test/ because it needs a live server:
//   1. start a server: python -m src.app.main --port 8830 --slots 0
//   2. MANET_TEST_PORT=8830 flutter test tool/layout_screenshots_test.dart
//      (MANET_SHOT_PANEL=1 also opens the controllers panel)
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:manet_desktop/l10n/app_localizations.dart';
import 'package:manet_desktop/screens/home_page/home_page_widget.dart';
import 'package:shared_preferences/shared_preferences.dart';

const sizes = <Size>[
  Size(1920, 1080),
  Size(1280, 720),
  Size(1024, 768),
  Size(1024, 600),
  Size(800, 600),
  Size(1366, 600),
  Size(720, 1000),
  Size(500, 900),
];

Future<void> _loadFont(String family, String path) async {
  final loader = FontLoader(family)..addFont(rootBundle.load(path));
  await loader.load();
}

/// On Windows, families the app doesn't bundle fall back to Segoe UI.
Future<void> _loadSystemFont(String family) async {
  final bytes = File(r'C:\Windows\Fonts\segoeui.ttf').readAsBytesSync();
  final loader = FontLoader(family)..addFont(Future.value(ByteData.sublistView(bytes)));
  await loader.load();
}

void main() {
  final port = int.parse(Platform.environment['MANET_TEST_PORT'] ?? '8830');
  final outDir = Platform.environment['MANET_SHOT_DIR'] ?? 'build/layout_shots';

  setUpAll(() async {
    HttpOverrides.global = null; // talk to the real dev server
    SharedPreferences.setMockInitialValues({'has_seen_onboarding': true});
    await _loadFont('momo', 'assets/fonts/Momo_Trust_Display/MomoTrustDisplay-Regular.ttf');
    await _loadFont('MaterialIcons', 'fonts/MaterialIcons-Regular.otf');
    for (final family in ['momo_sans', 'Roboto', 'Segoe UI']) {
      await _loadSystemFont(family);
    }
    Directory(outDir).createSync(recursive: true);
  });

  for (final size in sizes) {
    testWidgets('lobby ${size.width.toInt()}x${size.height.toInt()}', (tester) async {
      final overflows = <String>[];
      final previous = FlutterError.onError;
      FlutterError.onError = (details) {
        final text = details.exceptionAsString();
        if (text.contains('overflowed')) {
          overflows.add(text.split('\n').first);
        }
      };

      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      final key = GlobalKey();
      await tester.pumpWidget(
        AppLocalizations(
          notifier: LocaleNotifier(),
          child: RepaintBoundary(
            key: key,
            child: MaterialApp(
              debugShowCheckedModeBanner: false,
              home: HomePageScreen(host: '127.0.0.1', port: port, initialControllerMode: 'x360'),
            ),
          ),
        ),
      );

      // Let real network calls and the admin socket settle.
      for (var i = 0; i < 12; i++) {
        await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 250)));
        await tester.pump(const Duration(milliseconds: 250));
      }
      // Dismiss onboarding if it showed up.
      final skip = find.text('Pular');
      if (skip.evaluate().isNotEmpty) {
        await tester.tap(skip.first);
        await tester.pump(const Duration(seconds: 1));
      }
      await tester.pump(const Duration(seconds: 2));

      if (Platform.environment['MANET_SHOT_PANEL'] == '1') {
        await tester.tap(find.byIcon(Icons.sports_esports_rounded).first);
        for (var i = 0; i < 6; i++) {
          await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 250)));
          await tester.pump(const Duration(milliseconds: 250));
        }
      }

      final boundary = key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
      await tester.runAsync(() async {
        final image = await boundary.toImage(pixelRatio: 0.5);
        final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
        final prefix = Platform.environment['MANET_SHOT_PANEL'] == '1' ? 'panel' : 'lobby';
        File('$outDir/${prefix}_${size.width.toInt()}x${size.height.toInt()}.png')
            .writeAsBytesSync(bytes!.buffer.asUint8List());
      });

      FlutterError.onError = previous;
      // ignore: avoid_print
      print('SIZE ${size.width.toInt()}x${size.height.toInt()}: '
          '${overflows.isEmpty ? 'no overflow' : overflows.toSet().join(' | ')}');

      // Leave the lobby the way the power button does, then tear down.
      final navContext = tester.element(find.byType(HomePageScreen));
      Navigator.of(navContext).pushReplacement(
        MaterialPageRoute<void>(builder: (_) => const SizedBox()),
      );
      await tester.pump(const Duration(seconds: 1));
      await tester.pump(const Duration(seconds: 1));
      final leaveErrors = tester.takeException();
      // ignore: avoid_print
      print('LEAVE ${size.width.toInt()}: ${leaveErrors ?? 'clean'}');
      await tester.pumpWidget(const SizedBox());
      await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 200)));
    });
  }
}
