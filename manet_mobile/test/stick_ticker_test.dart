import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:manet_mobile/services/preferences_service.dart';
import 'package:manet_mobile/services/gamepad_input_engine.dart';

void main() {
  final engine = GamepadInputEngine.instance;
  late List<Map<String, dynamic>> sent;

  List<List<double>> sticks() => sent
      .where((p) => p['type'] == 'stick')
      .map((p) => [p['x'] as double, p['y'] as double])
      .toList();

  // Fixed left stick, 150px wide: its centre sits at (99, 317) in a 400x400
  // area, so 60px to the right is 0.8 deflection.
  const centre = Offset(99, 317);

  void touch() {
    engine.handleLeftPointerDown(
      event: const PointerDownEvent(pointer: 1, position: centre),
      parentSize: const Size(400, 400),
      mode: MovementMode.fixedJoystick,
      sensitivity: 1.0,
      converter: (p) => p,
      visualOffset: ValueNotifier(Offset.zero),
      active: ValueNotifier(false),
      basePos: ValueNotifier(Offset.zero),
      controlId: 'test',
      controlHashCode: 1,
      baseSize: 150,
    );
  }

  void move(double dx) => GestureBinding.instance.pointerRouter
      .route(PointerMoveEvent(pointer: 1, position: centre + Offset(dx, 0)));

  void lift() => GestureBinding.instance.pointerRouter
      .route(const PointerUpEvent(pointer: 1, position: centre));

  Future<void> frames(WidgetTester tester, int n) async {
    for (var i = 0; i < n; i++) {
      await tester.pump(const Duration(milliseconds: 17));
    }
  }

  bool ticking(WidgetTester tester) =>
      tester.binding.transientCallbackCount > 0;

  setUp(() => sent = []);
  tearDown(engine.dispose);

  testWidgets('no frames are asked for while no stick is held',
      (tester) async {
    engine.init(sent.add);
    await frames(tester, 5);
    expect(ticking(tester), isFalse);
    expect(sent, isEmpty);
  });

  testWidgets('letting go sends rest three times, then stops ticking',
      (tester) async {
    engine.init(sent.add);
    touch();
    expect(ticking(tester), isTrue);
    move(60);
    await frames(tester, 3);
    expect(sticks().last, [closeTo(0.8, 0.001), 0.0]);

    lift();
    await frames(tester, 6);
    final afterLift = sticks().skipWhile((s) => s[0] != 0.0).toList();
    expect(afterLift, [
      [0.0, 0.0],
      [0.0, 0.0],
      [0.0, 0.0],
    ]);
    expect(ticking(tester), isFalse);
  });

  testWidgets('a held stick keeps being resent while it does not move',
      (tester) async {
    engine.init(sent.add);
    touch();
    move(60);
    await frames(tester, 2);
    final before = sticks().length;
    await frames(tester, 12); // ~200ms, keep-alive every 50ms
    expect(sticks().length - before, greaterThanOrEqualTo(3));
    expect(ticking(tester), isTrue);
    lift();
    await frames(tester, 6);
  });

  testWidgets('touching again after a stop sends on the next frame',
      (tester) async {
    engine.init(sent.add);
    touch();
    move(60);
    await frames(tester, 2);
    lift();
    await frames(tester, 6);
    expect(ticking(tester), isFalse);

    sent.clear();
    touch();
    move(-60);
    await frames(tester, 1);
    expect(sticks(), [
      [closeTo(-0.8, 0.001), 0.0]
    ]);
    lift();
    await frames(tester, 6);
  });
}
