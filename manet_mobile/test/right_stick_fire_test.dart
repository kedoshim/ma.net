import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:manet_mobile/services/gamepad_input_engine.dart';
import 'package:manet_mobile/widgets/right_stick_controls.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final engine = GamepadInputEngine.instance;
  late List<Map<String, dynamic>> sent;
  late ValueNotifier<bool> firing;

  List<String> rtStates() => sent
      .where((p) => p['type'] == 'button' && p['id'] == 'RT')
      .map((p) => p['state'] as String)
      .toList();

  // Floating right stick: base centred where the finger lands, 150px wide,
  // so a 75px drag is full deflection.
  void touch(String mode,
      {Offset at = const Offset(200, 200), String button = 'RT'}) {
    engine.handleRightPointerDown(
      event: PointerDownEvent(pointer: 1, position: at),
      parentSize: const Size(400, 400),
      layout: 'RS_BUTTON',
      config: RightStickConfig(fireMode: mode, fireButton: button),
      converter: (p) => p,
      visualOffset: ValueNotifier(Offset.zero),
      active: ValueNotifier(false),
      basePos: ValueNotifier(Offset.zero),
      controlId: 'test',
      controlHashCode: 1,
      baseSize: 150,
      firing: firing,
    );
  }

  void move(double dx) => GestureBinding.instance.pointerRouter
      .route(PointerMoveEvent(pointer: 1, position: Offset(200 + dx, 200)));

  void lift() => GestureBinding.instance.pointerRouter
      .route(const PointerUpEvent(pointer: 1, position: Offset(200, 200)));

  setUp(() {
    sent = [];
    firing = ValueNotifier(false);
    engine.init(sent.add);
  });

  tearDown(engine.dispose);

  test('ring fires past 60% and lets go under 50%', () {
    touch(kFireRing);
    move(30); // 0.4
    expect(rtStates(), isEmpty);
    move(50); // 0.67
    expect(rtStates(), ['down']);
    expect(firing.value, isTrue);
    move(40); // 0.53: still inside the hysteresis band
    expect(rtStates(), ['down']);
    move(30); // 0.4
    expect(rtStates(), ['down', 'up']);
    expect(firing.value, isFalse);
    lift();
    expect(rtStates(), ['down', 'up']);
  });

  test('lifting the finger always lets go', () {
    touch(kFireRing);
    move(70);
    lift();
    expect(rtStates(), ['down', 'up']);
    expect(engine.isFiring, isFalse);
  });

  test('touch fires as soon as the stick is held', () {
    touch(kFireTouch);
    expect(rtStates(), ['down']);
    move(5);
    lift();
    expect(rtStates(), ['down', 'up']);
  });

  test('off never touches RT', () {
    touch(kFireOff);
    move(70);
    lift();
    expect(rtStates(), isEmpty);
  });

  test('a real RT button held keeps its press', () {
    engine.updateButtonState('RT', 'down', false);
    touch(kFireTouch);
    lift(); // the stick lets go, the button is still down
    expect(rtStates(), ['down']);
    engine.updateButtonState('RT', 'up', false);
    expect(rtStates(), ['down', 'up']);
  });

  test('a real RT button let go while the stick fires keeps it held', () {
    touch(kFireTouch);
    engine.updateButtonState('RT', 'down', false);
    engine.updateButtonState('RT', 'up', false);
    expect(rtStates(), ['down', 'down']);
    lift();
    expect(rtStates(), ['down', 'down', 'up']);
  });

  test('fires with the button picked', () {
    touch(kFireTouch, button: 'RB');
    lift();
    expect(
      sent.where((p) => p['type'] == 'button').map((p) => '${p['id']} ${p['state']}'),
      ['RB down', 'RB up'],
    );
  });
}
