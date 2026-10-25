import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:manet_mobile/services/gamepad_input_engine.dart';
import 'package:manet_mobile/widgets/action_buttons.dart';
import 'package:manet_mobile/widgets/right_stick_controls.dart';

void main() {
  late List<String> states;

  Future<void> pumpAimButton(WidgetTester tester, {bool firesOnRelease = false}) async {
    states = [];
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Center(
            // Like the real right side: an Expanded in a Row gives a fixed
            // width but a loose height.
            child: SizedBox(
              width: 120,
              height: 120,
              child: Row(
                children: [
                  Expanded(
                    child: AimButton(
                      label: 'RT',
                      onStateChange: states.add,
                      stickConfig: const RightStickConfig(),
                      firesOnRelease: firesOnRelease,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  testWidgets('fills its slot like a normal button', (tester) async {
    await pumpAimButton(tester);
    expect(tester.getSize(find.byType(AimButton)), const Size(120, 120));
    expect(tester.getSize(find.byType(GameButton)), const Size(120, 120));
  });

  testWidgets('a press without dragging is just the button', (tester) async {
    await pumpAimButton(tester);
    final gesture = await tester.startGesture(tester.getCenter(find.byType(AimButton)));
    await gesture.moveBy(const Offset(4, 0)); // under the slop
    expect(states, ['down']);
    expect(GamepadInputEngine.instance.isRightActive(), isFalse);
    await gesture.up();
    expect(states, ['down', 'up']);
    expect(GamepadInputEngine.instance.isRightActive(), isFalse);
  });

  testWidgets('dragging keeps the button held and aims', (tester) async {
    await pumpAimButton(tester);
    final gesture = await tester.startGesture(tester.getCenter(find.byType(AimButton)));
    await gesture.moveBy(const Offset(30, 0));
    await gesture.moveBy(const Offset(80, 0)); // well outside the button
    await tester.pump();
    expect(states, ['down']);
    expect(GamepadInputEngine.instance.isRightActive(), isTrue);
    await gesture.up();
    await tester.pump();
    expect(states, ['down', 'up']);
    expect(GamepadInputEngine.instance.isRightActive(), isFalse);
  });

  testWidgets('fire on release: nothing until the lift, then a tap', (tester) async {
    await pumpAimButton(tester, firesOnRelease: true);
    final gesture = await tester.startGesture(tester.getCenter(find.byType(AimButton)));
    await gesture.moveBy(const Offset(30, 0));
    await gesture.moveBy(const Offset(40, 0));
    await tester.pump();
    expect(states, isEmpty);
    expect(GamepadInputEngine.instance.isRightActive(), isTrue);

    await gesture.up();
    // Pressed at the lift with the aim still held...
    expect(states, ['down']);
    expect(GamepadInputEngine.instance.isRightActive(), isTrue);
    // ...then let go of the button, and after that of the aim.
    await tester.pump(const Duration(milliseconds: 70));
    expect(states, ['down', 'up']);
    expect(GamepadInputEngine.instance.isRightActive(), isTrue);
    await tester.pump(const Duration(milliseconds: 50));
    expect(GamepadInputEngine.instance.isRightActive(), isFalse);
  });

  testWidgets('fire on release: a quick tap still shoots', (tester) async {
    await pumpAimButton(tester, firesOnRelease: true);
    await tester.tap(find.byType(AimButton));
    expect(states, ['down']);
    await tester.pump(const Duration(milliseconds: 70));
    expect(states, ['down', 'up']);
    expect(GamepadInputEngine.instance.isRightActive(), isFalse);
  });
}
