import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:manet_desktop/screens/library/face_aquarium_sim.dart';

void run(AquariumSim sim, double seconds) {
  for (var t = 0.0; t < seconds; t += 1 / 60) {
    sim.step(1 / 60);
  }
}

void main() {
  test('faces are sized so about a hundred fill the box', () {
    final sim = AquariumSim()..size = const Size(1600, 800);
    final r = sim.faceRadius;
    final faceArea = math.pi * r * r;
    expect(1600 * 800 * 0.68 / faceArea, closeTo(100, 1));
  });

  test('thrown faces land and settle inside the box', () {
    final sim = AquariumSim(random: math.Random(1))..size = const Size(1200, 700);
    var landings = 0;
    sim.onLand = () => landings++;
    for (var i = 0; i < 40; i++) {
      sim.throwFace(i.isEven ? 'a' : 'b', i.isEven ? 0.3 : 0.7);
      run(sim, 0.05);
    }
    run(sim, 4);

    expect(sim.total, 40);
    expect(sim.perPlayer, {'a': 20, 'b': 20});
    expect(landings, 40);
    expect(sim.overflows, 0);
    expect(sim.faces, hasLength(40));
    for (final face in sim.faces) {
      final r = face.radius;
      expect(face.position.dx, inInclusiveRange(r - 0.5, 1200 - r + 0.5));
      expect(face.position.dy, inInclusiveRange(r, 700 - r + 0.5));
      // Resting on the pile, not drifting or jittering.
      expect(face.velocity.distance, lessThan(40));
    }
    // A pile, not faces inside each other.
    var worst = 0.0;
    for (final a in sim.faces) {
      for (final b in sim.faces) {
        if (identical(a, b)) continue;
        worst = math.max(worst, a.radius + b.radius - (a.position - b.position).distance);
      }
    }
    expect(worst, lessThan(4));
  });

  test('a full box drains out the bottom and keeps counting', () {
    final sim = AquariumSim(random: math.Random(2))..size = const Size(1200, 700);
    var overflows = 0;
    sim.onOverflow = () => overflows++;
    while (overflows == 0 && sim.total < 400) {
      // Four players tossing from their spots.
      sim.throwFace('p${sim.total % 4}', (sim.total % 4 + 1) / 5);
      run(sim, 1 / 15);
    }
    expect(overflows, 1);
    // Full at roughly the capacity, not long before or after.
    expect(sim.total, inInclusiveRange(80, 140));
    expect(sim.draining, isNotNull);
    final before = sim.faces.length;

    run(sim, AquariumSim.drainSeconds + 0.1);
    expect(sim.draining, isNull);
    expect(sim.faces.length, lessThan(before ~/ 4));

    final total = sim.total;
    sim.throwFace('a', 0.5);
    expect(sim.total, total + 1);
  });
}
