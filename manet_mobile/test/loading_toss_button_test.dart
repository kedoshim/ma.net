import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:manet_mobile/l10n/app_localizations.dart';
import 'package:manet_mobile/models/player_face.dart';
import 'package:manet_mobile/screens/controller_screen/controller_menu_view.dart';

void main() {
  const face = PlayerFaceData(
    color: Color(0xFF7C9CFF),
    faceText: ':)',
    rotation: PlayerFaceRotation.normal,
  );

  testWidgets('loading: every finger on the big button tosses a face (A)', (tester) async {
    tester.view.physicalSize = const Size(844, 390);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final sent = <String>[];

    await tester.pumpWidget(
      AppLocalizations(
        notifier: LocaleNotifier(),
        child: MaterialApp(
          home: Scaffold(
            body: ControllerMenuView(
              menuContext: MenuContext.loading,
              playerFace: face,
              onStickChanged: (_) {},
              onStickRelease: () {},
              onButtonStateChanged: (button, state) => sent.add('$button $state'),
              onOpenAvatar: () {},
              onOpenSeats: () {},
            ),
          ),
        ),
      ),
    );
    final strings = tester.element(find.byType(ControllerMenuView)).l10n.menu;
    final toss = find.byKey(const ValueKey('toss_button'));
    expect(toss, findsOneWidget);

    // Two thumbs alternating, the second down before the first lifts.
    final first = await tester.startGesture(tester.getCenter(toss));
    final second = await tester.startGesture(tester.getCenter(toss) + const Offset(30, 0));
    await first.up();
    final third = await tester.startGesture(tester.getCenter(toss));
    await second.up();
    await third.up();
    await tester.pump(const Duration(milliseconds: 500));

    expect(sent, ['A down', 'A up', 'A down', 'A up', 'A down', 'A up']);
    expect(find.text(strings.youTossed(3)), findsOneWidget);

    // START still shows the game.
    await tester.tap(find.text(strings.showGame));
    expect(sent.last, 'START up');
    expect(sent, contains('START down'));
  });
}
