import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:manet_mobile/services/gamepad_input_engine.dart';
import 'package:manet_mobile/widgets/action_buttons.dart';
import 'package:manet_mobile/widgets/right_stick_controls.dart';

void main() {
  late List<String> states;

  Future<void> pumpAimButton(WidgetTester tester) async {
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
}
