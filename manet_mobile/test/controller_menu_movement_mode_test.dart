import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:manet_mobile/l10n/app_localizations.dart';
import 'package:manet_mobile/models/player_face.dart';
import 'package:manet_mobile/screens/controller_screen/controller_default_view.dart';
import 'package:manet_mobile/screens/controller_screen/controller_menu_view.dart';
import 'package:manet_mobile/screens/controller_screen/controller_screen_widgets.dart';
import 'package:manet_mobile/services/preferences_service.dart';
import 'package:manet_mobile/widgets/embedded_video/embedded_video.dart';
import 'package:manet_mobile/widgets/joystick.dart';

Widget createTestApp(Widget child) {
  return AppLocalizations(
    notifier: LocaleNotifier(),
    child: MaterialApp(
      home: Scaffold(body: child),
    ),
  );
}

void main() {
  const face = PlayerFaceData(
    color: Color(0xFF7C9CFF),
    faceText: ':)',
    rotation: PlayerFaceRotation.normal,
  );

  testWidgets('Overlay defaults to DPad and cycles modes correctly', (tester) async {
    MovementMode? reportedMode;

    await tester.pumpWidget(
      createTestApp(
        ControllerMenuView(
          menuContext: MenuContext.overlay,
          playerFace: face,
          onStickChanged: (_) {},
          onStickRelease: () {},
          onButtonStateChanged: (_, __) {},
          onOpenAvatar: () {},
          onOpenSeats: () {},
          onMovementModeChanged: (mode) => reportedMode = mode,
        ),
      ),
    );
    await tester.pumpAndSettle();

    // Default mode for overlay must be D-Pad
    expect(find.byType(ControllerDpad), findsOneWidget);
    expect(find.byType(AdaptiveJoystick), findsNothing);
    expect(find.byType(Joystick), findsNothing);
    expect(find.byType(MovementModeToggleButton), findsOneWidget);

    // Toggle button -> switches to fixed joystick
    await tester.tap(find.byType(IconButton));
    await tester.pumpAndSettle();

    expect(reportedMode, MovementMode.fixedJoystick);
    expect(find.byType(Joystick), findsOneWidget);
    expect(find.byType(ControllerDpad), findsNothing);
    expect(find.byType(AdaptiveJoystick), findsNothing);

    // Toggle button -> switches to adaptive (floating) joystick
    await tester.tap(find.byType(IconButton));
    await tester.pumpAndSettle();

    expect(reportedMode, MovementMode.floatingJoystick);
    expect(find.byType(AdaptiveJoystick), findsOneWidget);
    expect(find.byType(Joystick), findsNothing);
    expect(find.byType(ControllerDpad), findsNothing);

    // Toggle button -> switches back to D-Pad
    await tester.tap(find.byType(IconButton));
    await tester.pumpAndSettle();

    expect(reportedMode, MovementMode.dpad);
    expect(find.byType(ControllerDpad), findsOneWidget);
  });

  testWidgets('Selector/Library defaults to Adaptive Joystick and cycles modes correctly', (tester) async {
    MovementMode? reportedMode;

    await tester.pumpWidget(
      createTestApp(
        ControllerMenuView(
          menuContext: MenuContext.library,
          playerFace: face,
          onStickChanged: (_) {},
          onStickRelease: () {},
          onButtonStateChanged: (_, __) {},
          onOpenAvatar: () {},
          onOpenSeats: () {},
          onMovementModeChanged: (mode) => reportedMode = mode,
        ),
      ),
    );
    await tester.pumpAndSettle();

    // Default mode for selector/library must be adaptive joystick
    expect(find.byType(AdaptiveJoystick), findsOneWidget);
    expect(find.byType(ControllerDpad), findsNothing);
    expect(find.byType(Joystick), findsNothing);
    expect(find.byType(MovementModeToggleButton), findsOneWidget);

    // Toggle button -> switches to D-Pad
    await tester.tap(find.byType(IconButton));
    await tester.pumpAndSettle();

    expect(reportedMode, MovementMode.dpad);
    expect(find.byType(ControllerDpad), findsOneWidget);
    expect(find.byType(AdaptiveJoystick), findsNothing);
  });

  testWidgets('Lobby defaults to Adaptive Joystick', (tester) async {
    await tester.pumpWidget(
      createTestApp(
        ControllerMenuView(
          menuContext: MenuContext.lobby,
          playerFace: face,
          onStickChanged: (_) {},
          onStickRelease: () {},
          onButtonStateChanged: (_, __) {},
          onOpenAvatar: () {},
          onOpenSeats: () {},
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byType(AdaptiveJoystick), findsOneWidget);
    expect(find.byType(ControllerDpad), findsNothing);
  });

  testWidgets('GameInfoPanel renders 2 columns with big cover on left and scrollable content on right', (tester) async {
    final game = {
      'id': 'overcooked',
      'name': 'Overcooked! All You Can Eat',
      'minPlayers': 1,
      'maxPlayers': 4,
      'tags': ['Cozinha', 'Party'],
      'trailerUrl': 'https://www.youtube.com/watch?v=123456',
      'screenshots': [
        'https://example.com/shot1.jpg',
        'https://example.com/shot2.jpg',
      ],
      'description': 'Um jogo caótico de culinária para jogar junto!',
      'coverUrl': '/api/games/overcooked/cover',
    };

    await tester.pumpWidget(
      createTestApp(
        GameInfoPanel(
          game: game,
          serverBase: Uri.parse('http://192.168.1.100:8000'),
        ),
      ),
    );
    await tester.pumpAndSettle();

    // Verify 2-column layout: Row with AspectRatio (cover) and Expanded (SingleChildScrollView)
    expect(find.byType(GameInfoPanel), findsOneWidget);
    expect(find.byType(AspectRatio), findsWidgets);
    expect(find.byType(SingleChildScrollView), findsOneWidget);

    // Verify right column contents in order:
    // 1. Name
    expect(find.text('Overcooked! All You Can Eat'), findsOneWidget);
    expect(find.text('Cozinha'), findsOneWidget);

    // 2. Trailer video card with button
    expect(find.text('Trailer'), findsOneWidget);

    // 3. Screenshots
    expect(find.byType(ListView), findsOneWidget);

    // 4. Description
    expect(find.text('Um jogo caótico de culinária para jogar junto!'), findsOneWidget);
  });

  test('Embedded video stub falls back correctly on VM / non-web', () {
    expect(isEmbeddedVideoSupported, isFalse);
    final widget = getEmbeddedVideo('123456');
    expect(widget, isA<SizedBox>());
  });
}

