import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:manet_mobile/widgets/right_stick_controls.dart';

/// The right column lays sticks out in a Column whose width is loose, like
/// ActionButtons does.
Widget _inRightColumn(RightStickConfig config) {
  return MaterialApp(
    home: Scaffold(
      body: Row(
        children: [
          const Expanded(child: SizedBox()),
          SizedBox(
            width: 220,
            child: Column(
              children: [
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.all(4),
                    child: FloatingRightStick(
                      output: RightStickOutput(
                        config: config,
                        onSendValue: (_, _) {},
                        onReleased: () {},
                      ),
                    ),
                  ),
                ),
                const Expanded(child: SizedBox()),
              ],
            ),
          ),
        ],
      ),
    ),
  );
}

void main() {
  for (final config in const [
    RightStickConfig(),
    RightStickConfig(fireMode: kFireRing),
  ]) {
    testWidgets('spawns centred under the finger (${config.fireMode})',
        (tester) async {
      await tester.pumpWidget(_inRightColumn(config));
      final cell = tester.getRect(find.byType(FloatingRightStick));
      final touch = cell.center + const Offset(-40, 15);

      final gesture = await tester.startGesture(touch);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      final base = tester.getCenter(find.byType(StickBase));
      expect((base - touch).distance, lessThan(1.0),
          reason: 'base at $base, finger at $touch');
      await gesture.up();
      await tester.pump(const Duration(milliseconds: 300));
    });
  }
}
