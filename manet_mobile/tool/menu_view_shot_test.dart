// Dev tool: screenshots of the phone's menu controls, seats sheet and swap
// offer into build/shots.   flutter test tool/menu_view_shot_test.dart
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:manet_mobile/l10n/app_localizations.dart';
import 'package:manet_mobile/models/player_face.dart';
import 'package:manet_mobile/screens/controller_screen/controller_menu_view.dart';

Future<void> _shot(WidgetTester tester, Widget child, String name, {Size? size}) async {
  tester.view.physicalSize = size ?? const Size(800, 380);
  final key = GlobalKey();
  await tester.pumpWidget(AppLocalizations(
    notifier: LocaleNotifier(),
    child: MaterialApp(
      debugShowCheckedModeBanner: false,
      home: RepaintBoundary(
        key: key,
        child: Scaffold(backgroundColor: const Color(0xFFE6F2FF), body: child),
      ),
    ),
  ));
  await tester.pump(const Duration(milliseconds: 300));
  final boundary = key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
  await tester.runAsync(() async {
    final image = await boundary.toImage(pixelRatio: 1);
    final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
    Directory('build/shots').createSync(recursive: true);
    File('build/shots/$name.png').writeAsBytesSync(bytes!.buffer.asUint8List());
  });
}

void main() {
  testWidgets('menu controls', (tester) async {
    for (final font in [
      ('momo', 'assets/fonts/Momo_Trust_Display/MomoTrustDisplay-Regular.ttf'),
      ('MaterialIcons', 'fonts/MaterialIcons-Regular.otf'),
    ]) {
      await (FontLoader(font.$1)..addFont(rootBundle.load(font.$2))).load();
    }
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    const face = PlayerFaceData(
      color: Color(0xFF7C9CFF),
      faceText: ':)',
      rotation: PlayerFaceRotation.normal,
    );
    Widget menu(MenuContext ctx) => ControllerMenuView(
          menuContext: ctx,
          ownerName: 'Ana',
          playerFace: face,
          onStickChanged: (_) {},
          onStickRelease: () {},
          onButtonStateChanged: (_, __) {},
          onOpenAvatar: () {},
          onOpenSeats: () {},
        );
    await _shot(tester, menu(MenuContext.library), 'menu_controls');
    await _shot(tester, menu(MenuContext.playground), 'menu_playground');
    await _shot(tester, menu(MenuContext.tournament), 'menu_tournament');

    final seats = {
      'slots': [
        {'slot': 0, 'player': {'deviceId': 'a', 'name': 'Ana', 'color': '#EF4444', 'faceText': ':D'}},
        {'slot': 1, 'player': {'deviceId': 'me', 'name': 'Bruno', 'color': '#2563EB', 'faceText': ':)'}},
        {'slot': 2, 'player': null},
      ],
      'bench': [
        {'deviceId': 'c', 'name': 'Carla', 'color': '#10B981', 'faceText': ';)'},
      ],
    };
    await _shot(
      tester,
      SeatsSheet(seats: seats, me: 'me', onAction: (_) {}),
      'seats_sheet',
      size: const Size(800, 560),
    );
    await _shot(
      tester,
      Center(
        child: SwapOfferDialog(
          from: const {'deviceId': 'a', 'name': 'Ana', 'color': '#EF4444', 'faceText': ':D'},
          fromSlot: 0,
          toSlot: 1,
        ),
      ),
      'swap_offer',
    );
  });
}
