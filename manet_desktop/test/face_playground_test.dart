import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:manet_desktop/models/player_face.dart';
import 'package:manet_desktop/screens/home_page/gamepad_state.dart';
import 'package:manet_desktop/screens/library/face_playground.dart';
import 'package:manet_desktop/services/host_api_service.dart';
import 'package:manet_desktop/widgets/player_face_indicator.dart';
import 'package:provider/provider.dart';

class _FakePads extends GamepadState {
  _FakePads() : super(HostApiService(host: '127.0.0.1', port: 1));

  final StreamController<PadButtonEvent> events = StreamController.broadcast();

  @override
  Stream<PadButtonEvent> get buttonEvents => events.stream;
}

DeviceModel _device(String id, Color color) => DeviceModel(
  id: id,
  name: id,
  connected: true,
  color: color,
  face: PlayerFaceData(color: color, faceText: ':)', rotation: PlayerFaceRotation.normal),
);

void main() {
  late _FakePads pads;

  Future<void> showPlayground(WidgetTester tester, List<String> ids) async {
    await tester.pumpWidget(
      ChangeNotifierProvider<GamepadState>.value(
        value: pads,
        child: MaterialApp(
          home: Center(
            child: SizedBox(
              width: 400,
              height: 300,
              child: FacePlayground(deviceIds: ids, random: math.Random(7)),
            ),
          ),
        ),
      ),
    );
  }

  /// [visible] lets a test start with only some of the players in the box.
  Future<void> pumpPlayground(
    WidgetTester tester,
    List<String> ids, {
    List<String>? visible,
  }) async {
    pads = _FakePads();
    pads.slots = [
      for (var i = 0; i < ids.length; i++)
        SlotModel(slot: i, device: _device(ids[i], Colors.primaries[i])),
    ];
    await showPlayground(tester, visible ?? ids);
  }

  Offset centerOf(WidgetTester tester, int index) =>
      tester.getCenter(find.byType(PlayerFaceIndicator).at(index));

  Future<void> run(WidgetTester tester, Duration duration) async {
    final frames = duration.inMilliseconds ~/ 16;
    for (var i = 0; i < frames; i++) {
      await tester.pump(const Duration(milliseconds: 16));
    }
  }

  testWidgets('a ball falls, rests on the floor and jumps with A', (tester) async {
    await pumpPlayground(tester, ['a']);
    await run(tester, const Duration(seconds: 2));
    final resting = centerOf(tester, 0).dy;

    pads.events.add(const PadButtonEvent('a', 'A', true));
    await run(tester, const Duration(milliseconds: 150));
    final inAir = centerOf(tester, 0).dy;
    expect(inAir, lessThan(resting - 40), reason: 'jump should lift the ball');

    await run(tester, const Duration(seconds: 2));
    expect(centerOf(tester, 0).dy, closeTo(resting, 1.5), reason: 'it lands again');
  });

  testWidgets('a player can jump onto another and stay on top', (tester) async {
    await pumpPlayground(tester, ['a', 'b'], visible: ['a']);
    // 'a' is alone first and parks against the right wall.
    pads.updateJoystick('a', 1, 0);
    await run(tester, const Duration(seconds: 2));
    pads.updateJoystick('a', 0, 0);
    // Then 'b' drops in, backs off to the left...
    await showPlayground(tester, ['a', 'b']);
    pads.updateJoystick('b', -1, 0);
    await run(tester, const Duration(seconds: 2));
    // ...and runs right, jumping, until it lands on 'a'.
    pads.updateJoystick('b', 1, 0);
    for (var i = 0; i < 6; i++) {
      pads.events.add(const PadButtonEvent('b', 'A', true));
      await run(tester, const Duration(milliseconds: 500));
    }
    pads.updateJoystick('b', 0, 0);
    await run(tester, const Duration(seconds: 2));
    final a = centerOf(tester, 0);
    final b = centerOf(tester, 1);
    expect(b.dy, lessThan(a.dy - 40), reason: 'b should be standing on a');
  });
}
