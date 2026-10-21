import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:manet_mobile/l10n/app_localizations.dart';
import 'package:manet_mobile/models/controller_branding.dart';
import 'package:manet_mobile/models/controller_layout_preset.dart';
import 'package:manet_mobile/models/controller_left_zone.dart';
import 'package:manet_mobile/models/player_face.dart';
import 'package:manet_mobile/screens/controller_screen/controller_default_view.dart';
import 'package:manet_mobile/screens/controller_screen/controller_screen_types.dart';
import 'package:manet_mobile/services/preferences_service.dart';
import 'package:manet_mobile/widgets/action_buttons.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _face = PlayerFaceData(
  color: Color(0xFF7C9CFF),
  faceText: ':)',
  rotation: PlayerFaceRotation.normal,
);

Widget _controller({
  required List<String> leftButtons,
  required Map<String, bool> visible,
}) {
  return AppLocalizations(
    notifier: LocaleNotifier(),
    child: MaterialApp(
      home: Scaffold(
        body: ControllerDefaultView(
          brandingMode: ControllerBrandingMode.xinput,
          movementMode: MovementMode.dpad,
          onMovementModeChanged: (_) {},
          onStickChanged: (_) {},
          onStickRelease: () {},
          onButtonStateChanged: (_, __) {},
          onOpenOptions: () {},
          onOpenFaceEditor: () {},
          onOpenEditControls: () {},
          onRetryConnection: () {},
          onOpenQrScanner: null,
          connectionState: ControllerConnectionState.connected,
          status: '',
          playerFace: _face,
          playerColor: null,
          playerIndex: 0,
          totalSlots: 4,
          visibleButtons: ControllerBranding.normalizeVisibility(visible),
          buttonOrder: ControllerBranding.canonicalOrder,
          hasVacantSlot: false,
          onJoinGame: null,
          playerName: 'P1',
          onNameChanged: (_) {},
          onRequestRandomName: () async => '',
          buttonSizes: const {},
          rightLayoutMode: 'rows',
          leftStickSensitivity: 1,
          rightStickSensitivity: 1,
          swipeAccelerationIntensity: 0,
          rightStickAntiDeadzone: 0.1,
          rightStickResponseCurve: 0.5,
          isPanelExpanded: false,
          panelMode: ControllerPanelMode.use,
          onPanelExpandedChanged: (_) {},
          onPanelModeChanged: (_) {},
          editableButtons: const [],
          onSetButtonVisibility: (_, __) {},
          onButtonOrderChanged: (_) {},
          onButtonSizesChanged: (_) {},
          onRightLayoutModeChanged: (_) {},
          tapHapticsEnabled: false,
          onTapHapticsToggled: () {},
          leftButtons: leftButtons,
        ),
      ),
    ),
  );
}

/// The test font is wider than the real one, so the off-screen secondary
/// panel overflows; that says nothing about the left row.
void _ignoreOverflow() {
  final original = FlutterError.onError;
  FlutterError.onError = (details) {
    if (details.toString().contains('overflowed')) return;
    original?.call(details);
  };
  addTearDown(() => FlutterError.onError = original);
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('left row takes at most two buttons and never a stick', () {
    expect(normalizeLeftButtons(['lt', 'LT', 'RS_FIXED', 'LB', 'A']), ['LT', 'LB']);
  });

  test('presets without the field keep the left side as it was', () {
    final preset = ControllerLayoutPreset.fromJson({
      'layout': {'visibleButtons': {'A': true}},
    });
    expect(preset.leftButtons, isEmpty);
  });

  testWidgets('a left-row button leaves the right grid', (tester) async {
    tester.view.physicalSize = const Size(2400, 1080);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    _ignoreOverflow();

    await tester.pumpWidget(_controller(
      leftButtons: const ['LT'],
      visible: const {'LT': true, 'RT': true, 'A': true},
    ));
    await tester.pump();

    final rightGrid = find.byType(ActionButtons);
    expect(
      find.descendant(of: rightGrid, matching: find.byType(GameButton)),
      findsNWidgets(2),
    );
    // LT is still on screen, just above the D-pad.
    final leftSide = find
        .ancestor(of: find.byType(ControllerDpad), matching: find.byType(Column))
        .first;
    expect(
      find.descendant(of: leftSide, matching: find.byType(GameButton)),
      findsOneWidget,
    );
  });

  testWidgets('no left row: same controller as before', (tester) async {
    tester.view.physicalSize = const Size(2400, 1080);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    _ignoreOverflow();

    await tester.pumpWidget(_controller(
      leftButtons: const [],
      visible: const {'LT': true, 'RT': true, 'A': true},
    ));
    await tester.pump();

    expect(
      find.descendant(of: find.byType(ActionButtons), matching: find.byType(GameButton)),
      findsNWidgets(3),
    );
  });
}
