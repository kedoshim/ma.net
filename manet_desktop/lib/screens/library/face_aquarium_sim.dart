import 'dart:math' as math;
import 'dart:ui' show Offset, Size;

/// One face thrown into the box.
class AquariumFace {
  AquariumFace(this.id, this.ownerId, this.position, this.velocity, this.radius, this.spin);

  final int id;
  final String ownerId;
  final double radius;
  Offset position;
  Offset velocity;
  double angle = 0;
  double spin;
  /// Seconds since thrown (it pops in) and since it first touched the
  /// floor or the pile (it squashes); null until it does.
  double age = 0;
  double? landedAge;
}

/// The loading screen's box as plain Dart (tested in the VM): every button
/// press throws one of the player's faces in, they fall and pile up, and
/// when the pile reaches the top the floor opens and drains everything so
/// the throwing never has to stop.
///
/// Faces are moved with position-based steps (move, push apart, read the
/// velocity back from how far they moved): a big pile stays calm instead of
/// jittering the way velocity impulses do.
class AquariumSim {
  AquariumSim({math.Random? random}) : _random = random ?? math.Random();

  /// About this many faces fill the box; their size comes from it.
  static const int capacity = 100;
  static const double drainSeconds = 1.6;
  /// More faces than this and the box drains anyway (a pile that never
  /// settles enough to count as full).
  static const int maxFaces = capacity * 2;
  static const double _gravity = 2300;
  static const double _drainGravity = 3200;
  static const int _substeps = 2;
  static const int _iterations = 3;

  final math.Random _random;
  final List<AquariumFace> faces = [];

  Size size = Size.zero;
  double time = 0;
  int total = 0;
  final Map<String, int> perPlayer = {};
  int overflows = 0;
  /// Seconds left with the floor open; null when closed.
  double? draining;

  /// Called when a face first lands (for a bloop) and when the box
  /// overflows.
  void Function()? onLand;
  void Function()? onOverflow;

  /// Typical face radius (each one is a bit bigger or smaller, so the pile
  /// stays messy instead of stacking into neat rows): [capacity] of them
  /// fill the box. A tossed
  /// pile leaves gaps and heaps up in the middle, so they cover about 68%
  /// of it when the top is reached (measured: 0.78 filled at 67-103).
  double get faceRadius {
    if (size.isEmpty) return 30;
    final r = math.sqrt(size.width * size.height * 0.68 / (capacity * math.pi));
    return r.clamp(16.0, 90.0);
  }

  /// Throws a face of [ownerId] from above, around [laneX] (0..1).
  void throwFace(String ownerId, double laneX) {
    total++;
    perPlayer[ownerId] = (perPlayer[ownerId] ?? 0) + 1;
    if (size.isEmpty) return;
    // Uniform 0.7..1.3: the average area stays that of [faceRadius].
    final r = faceRadius * (0.7 + _random.nextDouble() * 0.6);
    final x = (laneX * size.width + (_random.nextDouble() - 0.5) * size.width * 0.12)
        .clamp(r, size.width - r);
    // Tossed in a lob toward the middle, never straight down.
    final towardMiddle = (size.width / 2 - x) / size.width;
    faces.add(
      AquariumFace(
        total,
        ownerId,
        Offset(x, -r),
        Offset(
          towardMiddle * 500 + (_random.nextDouble() - 0.5) * 420,
          300 + _random.nextDouble() * 300,
        ),
        r,
        (_random.nextDouble() - 0.5) * 14,
      ),
    );
  }

  void step(double dt) {
    // Velocities are read back as distance / dt: a zero step would be NaN.
    if (size.isEmpty || dt <= 0) return;
    time += dt;
    final h = dt / _substeps;
    for (var i = 0; i < _substeps; i++) {
      _move(h);
      for (var k = 0; k < _iterations; k++) {
        _separate();
        for (final face in faces) {
          _walls(face);
        }
      }
      for (final face in faces) {
        var v = (face.position - _before[face]!) / h;
        // Landed faces lose speed fast, so the pile settles.
        if (face.landedAge != null) v *= math.max(0, 1 - 3 * h);
        face.velocity = v;
      }
    }
    for (final face in faces) {
      face.age += dt;
      if (face.landedAge != null) face.landedAge = face.landedAge! + dt;
    }
    _drain(dt);
    _checkOverflow();
  }

  final Map<AquariumFace, Offset> _before = {};

  void _move(double h) {
    _before.clear();
    final gravity = draining != null ? _drainGravity : _gravity;
    for (final face in faces) {
      _before[face] = face.position;
      final v = face.velocity + Offset(0, gravity * h);
      face.position += v * h;
      // Spin in the air; once landed roll a little with sideways motion
      // and settle back upright, so the faces can be read.
      if (face.landedAge != null) {
        final tilt = math.atan2(math.sin(face.angle), math.cos(face.angle));
        face.angle += v.dx * h / face.radius * 0.35 - tilt * 3 * h;
      } else {
        face.angle += face.spin * h;
      }
    }
  }

  void _land(AquariumFace face) {
    if (face.landedAge != null) return;
    face.landedAge = 0;
    onLand?.call();
  }

  /// Pushes overlapping faces apart, through a grid so only neighbors are
  /// compared.
  void _separate() {
    // Two of the biggest faces must fit in a cell for neighbors to meet.
    final cell = faceRadius * 2.7;
    final grid = <int, List<AquariumFace>>{};
    int key(int cx, int cy) => cx * 100003 + cy;
    for (final face in faces) {
      final cx = (face.position.dx / cell).floor();
      final cy = (face.position.dy / cell).floor();
      (grid[key(cx, cy)] ??= []).add(face);
    }
    for (final face in faces) {
      final cx = (face.position.dx / cell).floor();
      final cy = (face.position.dy / cell).floor();
      for (var dx = -1; dx <= 1; dx++) {
        for (var dy = -1; dy <= 1; dy++) {
          final others = grid[key(cx + dx, cy + dy)];
          if (others == null) continue;
          for (final other in others) {
            if (other.id <= face.id) continue;
            _pushApart(face, other);
          }
        }
      }
    }
  }

  void _pushApart(AquariumFace a, AquariumFace b) {
    final delta = b.position - a.position;
    final distance = delta.distance;
    final min = a.radius + b.radius;
    if (distance >= min) return;
    final normal = distance == 0 ? const Offset(1, 0) : delta / distance;
    final push = normal * ((min - distance) / 2);
    a.position -= push;
    b.position += push;
    // Hitting the pile counts as landing.
    if (a.landedAge != null) _land(b);
    if (b.landedAge != null) _land(a);
  }

  void _walls(AquariumFace face) {
    final r = face.radius;
    var p = face.position;
    if (p.dx < r) p = Offset(r, p.dy);
    if (p.dx > size.width - r) p = Offset(size.width - r, p.dy);
    if (draining == null && p.dy > size.height - r) {
      p = Offset(p.dx, size.height - r);
      _land(face);
    }
    face.position = p;
  }

  void _drain(double dt) {
    final left = draining;
    if (left == null) return;
    faces.removeWhere((f) => f.position.dy - f.radius > size.height);
    draining = left - dt;
    if (draining! <= 0) {
      draining = null;
      // Whoever is still stuck in the floor's opening goes too.
      faces.removeWhere((f) => f.position.dy + f.radius > size.height);
    }
  }

  /// Full when a face resting on the pile pokes out of the top.
  void _checkOverflow() {
    if (draining != null) return;
    final full = faces.length >= maxFaces ||
        faces.any(
          (f) =>
              (f.landedAge ?? 0) > 0.6 &&
              f.velocity.distance < 80 &&
              f.position.dy - f.radius < 0,
        );
    if (!full) return;
    overflows++;
    draining = drainSeconds;
    onOverflow?.call();
  }
}
