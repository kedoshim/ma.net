import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:provider/provider.dart';

import '../../theme/app_colors.dart';
import '../../widgets/player_face_indicator.dart';
import '../home_page/gamepad_state.dart';

/// Which area of the playground a face is in (null: none).
typedef PlaygroundZoneOf = String? Function(Offset center, Size size);

/// Where (and how fast) a face enters the playground.
class PlaygroundSpawn {
  final Offset position;
  final Offset velocity;

  const PlaygroundSpawn(this.position, [this.velocity = Offset.zero]);
}

/// Default radius of a face in the playground.
const double kPlaygroundFaceRadius = 34;

/// Height of the floor band (styled like the game library's footer).
const double kPlaygroundFloorHeight = 62;

/// A box where players play with their faces: round bodies with gravity
/// that roll with the stick, jump with Select (A) and can stand on top of
/// each other. Holding the emote button (Y) blows the face up dramatically,
/// the longer the bigger, shoving whoever it touches. Used while waiting for
/// the overlay owner, in the console lobby and in the lineup.
class FacePlayground extends StatefulWidget {
  final List<String> deviceIds;

  /// Where new faces drop in; tests pass a seeded one.
  final math.Random? random;

  /// Size of the faces.
  final double radius;

  /// Rounded border around the box.
  final bool framed;

  /// Drawn behind the faces (the lobby's "play" area, the lineup's sides).
  final Widget Function(BuildContext context, Size size)? background;

  /// Areas faces can stand in; [onZoneChanged] fires when one changes.
  final PlaygroundZoneOf? zoneOf;
  final void Function(String deviceId, String? zone)? onZoneChanged;

  /// Player names under the faces; [labelOf] can change the text.
  final bool nameTags;
  final String Function(String deviceId, String name)? labelOf;

  /// Names above the faces instead of below.
  final bool nameTagsAbove;

  /// No wall on the right: a face rolling past the edge leaves the
  /// playground and [onExitRight] fires (console lobby: "ready").
  final bool openRight;
  final ValueChanged<String>? onExitRight;

  /// Where a face that (re)joins enters; null drops it from the top.
  final PlaygroundSpawn? Function(String deviceId, Size size)? spawnOf;

  /// Solid rectangles faces collide with and can stand on.
  final List<Rect> Function(Size size)? obstacles;

  /// A floor band at the bottom, like the game library's footer.
  final bool floor;

  /// Filled with each face's position every frame (the last one stays after
  /// a face leaves), so the owner knows where someone was.
  final Map<String, Offset>? positions;

  const FacePlayground({
    super.key,
    required this.deviceIds,
    this.random,
    this.radius = kPlaygroundFaceRadius,
    this.framed = true,
    this.background,
    this.zoneOf,
    this.onZoneChanged,
    this.nameTags = false,
    this.labelOf,
    this.nameTagsAbove = false,
    this.openRight = false,
    this.onExitRight,
    this.spawnOf,
    this.obstacles,
    this.floor = false,
    this.positions,
  });

  @override
  State<FacePlayground> createState() => _FacePlaygroundState();
}

class _Ball {
  _Ball(this.id, this.position, this.baseRadius);

  final String id;
  final double baseRadius;
  Offset position;
  Offset velocity = Offset.zero;
  double angle = 0;
  /// On the floor or a platform: rolling friction applies.
  bool grounded = false;
  /// Resting on someone's head: can jump off it, but nothing holds it
  /// there — it slides off unless balanced.
  bool onHead = false;
  bool steering = false;
  String? zone;

  /// D-pad directions held (LEFT / RIGHT steer like the stick).
  final Set<String> dpad = {};

  /// Emote: blown up while held. [scale] springs toward the target.
  double? heldSince;
  double scale = 1;
  double scaleVelocity = 0;

  /// How fast the radius grows (px/s); growing faces shove the others.
  double growth = 0;

  double get r => baseRadius * scale;
}

class _FacePlaygroundState extends State<FacePlayground>
    with SingleTickerProviderStateMixin {
  // A face that left through the right edge waits this long for the session
  // to take it out of [deviceIds] before it rolls back in.
  static const Duration _exitGrace = Duration(seconds: 3);
  static const double _gravity = 2100;
  static const double _jumpSpeed = 900;
  static const double _groundAccel = 3200;
  static const double _airAccel = 1500;
  static const double _maxSpeed = 560;
  static const double _deadZone = 0.15;
  static const int _substeps = 4;
  // Emote: holding Y grows the face up to this scale over [_growSeconds].
  static const double _maxGrow = 2.6;
  static const double _growSeconds = 1.4;
  static const double _shove = 2.4;

  final Map<String, _Ball> _balls = {};
  final Map<String, DateTime> _exited = {};
  List<Rect> _obstacles = const [];
  final ValueNotifier<int> _frame = ValueNotifier(0);
  late final math.Random _random = widget.random ?? math.Random();
  late final Ticker _ticker;
  StreamSubscription<PadButtonEvent>? _buttons;
  Size _size = Size.zero;
  Duration _last = Duration.zero;
  double _now = 0;

  @override
  void initState() {
    super.initState();
    _ticker = createTicker(_tick)..start();
    _buttons = context.read<GamepadState>().buttonEvents.listen(_onButton);
  }

  @override
  void dispose() {
    _ticker.dispose();
    _buttons?.cancel();
    _frame.dispose();
    super.dispose();
  }

  void _onButton(PadButtonEvent event) {
    final ball = _balls[event.deviceId];
    if (ball == null) return;
    if (event.button == 'Y') {
      ball.heldSince = event.pressed ? (ball.heldSince ?? _now) : null;
      return;
    }
    if (event.button == 'LEFT' || event.button == 'RIGHT') {
      event.pressed ? ball.dpad.add(event.button) : ball.dpad.remove(event.button);
      return;
    }
    // Jump: A, or up on the D-pad.
    if ((event.button == 'A' || event.button == 'UP') &&
        event.pressed &&
        (ball.grounded || ball.onHead)) {
      ball.velocity = Offset(ball.velocity.dx, -_jumpSpeed);
      ball.grounded = false;
      ball.onHead = false;
    }
  }

  void _syncBalls() {
    _balls.removeWhere((id, _) => !widget.deviceIds.contains(id));
    _exited.removeWhere((id, _) => !widget.deviceIds.contains(id));
    final now = DateTime.now();
    final radius = widget.radius;
    for (final id in widget.deviceIds) {
      if (_balls.containsKey(id)) continue;
      final exitedAt = _exited[id];
      if (exitedAt != null && now.difference(exitedAt) < _exitGrace) continue;
      _exited.remove(id);
      final spawn = widget.spawnOf?.call(id, _size);
      _balls[id] = _Ball(
        id,
        spawn?.position ??
            Offset(
              radius +
                  _random.nextDouble() * math.max(1, _size.width - 2 * radius),
              radius + 4,
            ),
        radius,
      )..velocity = spawn?.velocity ?? Offset.zero;
    }
  }

  void _tick(Duration elapsed) {
    final dt = _last == Duration.zero
        ? 1 / 60
        : math.min(1 / 30, (elapsed - _last).inMicroseconds / 1e6);
    _last = elapsed;
    _now = elapsed.inMicroseconds / 1e6;
    if (_size.isEmpty) return;
    _syncBalls();
    _obstacles = widget.obstacles?.call(_size) ?? const [];
    for (final ball in _balls.values) {
      _grow(ball, dt);
    }
    final gamepads = context.read<GamepadState>();
    final step = dt / _substeps;
    for (var i = 0; i < _substeps; i++) {
      _step(step, gamepads);
    }
    final positions = widget.positions;
    if (positions != null) {
      for (final ball in _balls.values) {
        positions[ball.id] = ball.position;
      }
    }
    _removeExited();
    _reportZones();
    _frame.value++;
  }

  /// Emote: a springy scale toward the held target (and back to 1 with a
  /// wobble when released).
  void _grow(_Ball ball, double dt) {
    final held = ball.heldSince == null ? null : _now - ball.heldSince!;
    final target = held == null
        ? 1.0
        : 1 +
              (_maxGrow - 1) *
                  Curves.easeOutCubic.transform(
                    math.min(1, held / _growSeconds),
                  );
    final before = ball.r;
    ball.scaleVelocity +=
        ((target - ball.scale) * 260 - ball.scaleVelocity * 16) * dt;
    ball.scale = math.max(0.6, ball.scale + ball.scaleVelocity * dt);
    ball.growth = (ball.r - before) / dt;
  }

  void _step(double dt, GamepadState gamepads) {
    final balls = _balls.values.toList();
    for (final ball in balls) {
      var stick = gamepads.inputListenable(ball.id).value.stickX;
      if (stick.abs() <= _deadZone && ball.dpad.isNotEmpty) {
        stick = (ball.dpad.contains('RIGHT') ? 1.0 : 0.0) - (ball.dpad.contains('LEFT') ? 1.0 : 0.0);
      }
      ball.steering = stick.abs() > _deadZone;
      var vx = ball.velocity.dx;
      var vy = ball.velocity.dy + _gravity * dt;
      if (stick.abs() > _deadZone) {
        vx += stick * (ball.grounded ? _groundAccel : _airAccel) * dt;
      } else if (ball.grounded) {
        vx *= math.max(0, 1 - 7 * dt); // rolling friction
      }
      vx = vx.clamp(-_maxSpeed, _maxSpeed);
      ball.velocity = Offset(vx, vy);
      ball.position += ball.velocity * dt;
      ball.angle += vx * dt / ball.r;
      ball.grounded = false;
      ball.onHead = false;
      _collideWalls(ball);
      for (final rect in _obstacles) {
        _collideRect(ball, rect);
      }
    }
    for (var a = 0; a < balls.length; a++) {
      for (var b = a + 1; b < balls.length; b++) {
        _collideBalls(balls[a], balls[b]);
      }
    }
  }

  void _removeExited() {
    if (!widget.openRight) return;
    final gone = [
      for (final ball in _balls.values)
        if (ball.position.dx > _size.width + ball.r) ball.id,
    ];
    for (final id in gone) {
      _balls.remove(id);
      _exited[id] = DateTime.now();
      widget.onExitRight?.call(id);
    }
  }

  void _reportZones() {
    final zoneOf = widget.zoneOf;
    if (zoneOf == null) return;
    for (final ball in _balls.values) {
      final zone = zoneOf(ball.position, _size);
      if (zone != ball.zone) {
        ball.zone = zone;
        widget.onZoneChanged?.call(ball.id, zone);
      }
    }
  }

  double get _floorY =>
      _size.height - (widget.floor ? kPlaygroundFloorHeight : 0);

  void _collideWalls(_Ball ball) {
    final r = ball.r;
    var p = ball.position;
    var v = ball.velocity;
    if (p.dx < r) {
      p = Offset(r, p.dy);
      v = Offset(-v.dx * 0.4, v.dy);
    } else if (!widget.openRight && p.dx > _size.width - r) {
      p = Offset(_size.width - r, p.dy);
      v = Offset(-v.dx * 0.4, v.dy);
    }
    if (p.dy > _floorY - r) {
      p = Offset(p.dx, _floorY - r);
      v = Offset(v.dx, v.dy > 120 ? -v.dy * 0.25 : 0);
      ball.grounded = true;
    } else if (p.dy < r) {
      p = Offset(p.dx, r);
      v = Offset(v.dx, v.dy.abs() * 0.3);
    }
    ball.position = p;
    ball.velocity = v;
  }

  /// A face against a solid rectangle: pushed out along the closest side;
  /// the top works as ground.
  void _collideRect(_Ball ball, Rect rect) {
    final r = ball.r;
    final p = ball.position;
    final closest = Offset(
      p.dx.clamp(rect.left, rect.right),
      p.dy.clamp(rect.top, rect.bottom),
    );
    var delta = p - closest;
    var distance = delta.distance;
    if (distance >= r) return;
    if (distance == 0) {
      // Center inside the rectangle: leave through the top.
      delta = const Offset(0, -1);
      ball.position = Offset(p.dx, rect.top - r);
    } else {
      ball.position = closest + delta / distance * r;
    }
    final normal = distance == 0 ? delta : delta / distance;
    final into = ball.velocity.dx * normal.dx + ball.velocity.dy * normal.dy;
    if (into < 0) {
      ball.velocity -= normal * (into * (normal.dy < -0.6 ? 1.0 : 1.4));
    }
    if (normal.dy < -0.6) ball.grounded = true;
  }

  void _collideBalls(_Ball a, _Ball b) {
    final delta = b.position - a.position;
    final distance = delta.distance;
    final minDistance = a.r + b.r;
    if (distance >= minDistance || distance == 0) return;
    final normal = delta / distance;
    final overlap = minDistance - distance;

    // A face blowing up shoves whoever it touches, harder the faster it
    // grows.
    if (a.growth > 0) b.velocity += normal * (a.growth * _shove);
    if (b.growth > 0) a.velocity -= normal * (b.growth * _shove);

    // Resting on someone counts as support for jumping.
    if (normal.dy < -0.5) b.onHead = true;
    if (normal.dy > 0.5) a.onHead = true;

    final ma = a.r * a.r;
    final mb = b.r * b.r;
    final _Ball? upper = normal.dy < -0.5 ? b : (normal.dy > 0.5 ? a : null);
    if (upper != null) {
      // One on top of the other: only the upper one is pushed out, so the
      // lower one isn't pressed into the floor.
      final up = identical(upper, b) ? normal : -normal; // lower -> upper
      upper.position += up * overlap;
    } else {
      // Side by side: pushed apart by weight (bigger faces move less).
      a.position -= normal * (overlap * mb / (ma + mb));
      b.position += normal * (overlap * ma / (ma + mb));
    }

    // Exchange velocity along the normal: an upper face sliding down the
    // curve shoves the lower one sideways, so both roll.
    final relative =
        (b.velocity - a.velocity).dx * normal.dx +
        (b.velocity - a.velocity).dy * normal.dy;
    if (relative < 0) {
      final impulse = -(1 + 0.1) * relative;
      a.velocity -= normal * (impulse * mb / (ma + mb));
      b.velocity += normal * (impulse * ma / (ma + mb));
    }

    // Some grip when standing near the top of someone's head: you can stay
    // up there if you land centered and keep still, and you get carried a
    // little when the one below moves, until you lose balance and fall.
    if (upper != null) {
      final lower = identical(upper, b) ? a : b;
      final up = identical(upper, b) ? normal : -normal;
      if (!upper.steering && up.dx.abs() < 0.35 && upper.growth <= 0 && lower.growth <= 0) {
        final tangent = Offset(-up.dy, up.dx);
        final slip = upper.velocity - lower.velocity;
        final along = slip.dx * tangent.dx + slip.dy * tangent.dy;
        upper.velocity -= tangent * (along * 0.5);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final gamepads = context.watch<GamepadState>();
    return Container(
      decoration: widget.framed
          ? BoxDecoration(
              color: AppColors.screenBackground.withValues(alpha: 0.92),
              borderRadius: BorderRadius.circular(28),
              border: Border.all(color: AppColors.textPrimary, width: 4),
            )
          : null,
      clipBehavior: widget.framed ? Clip.antiAlias : Clip.none,
      child: LayoutBuilder(
        builder: (context, constraints) {
          _size = constraints.biggest;
          return Stack(
            children: [
              if (widget.background != null)
                Positioned.fill(child: widget.background!(context, _size)),
              if (widget.floor)
                Positioned(
                  left: 0,
                  right: 0,
                  bottom: 0,
                  height: kPlaygroundFloorHeight,
                  child: Container(
                    decoration: const BoxDecoration(
                      color: AppColors.lightColor,
                      border: Border(
                        top: BorderSide(color: AppColors.textPrimary, width: 4),
                      ),
                    ),
                  ),
                ),
              Positioned.fill(
                child: ValueListenableBuilder<int>(
                  valueListenable: _frame,
                  builder: (context, _, _) => Stack(
                    clipBehavior: Clip.none,
                    children: [
                      for (final ball in _balls.values)
                        if (gamepads.deviceById(ball.id)
                            case final device?) ...[
                          if (widget.nameTags)
                            Positioned(
                              left: ball.position.dx - 80,
                              top: widget.nameTagsAbove
                                  ? ball.position.dy - ball.r - 26
                                  : ball.position.dy + ball.r + 2,
                              width: 160,
                              child: Text(
                                widget.labelOf?.call(ball.id, device.name) ??
                                    device.name,
                                textAlign: TextAlign.center,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontFamily: 'momo',
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                  color: AppColors.textPrimary,
                                ),
                              ),
                            ),
                          () {
                            // Held at full size: it trembles, about to burst.
                            final straining =
                                ball.heldSince != null &&
                                _now - ball.heldSince! > _growSeconds;
                            final shake = straining
                                ? Offset(
                                    math.sin(_now * 90) * 3,
                                    math.cos(_now * 77) * 3,
                                  )
                                : Offset.zero;
                            return Positioned(
                              key: ValueKey('face-${ball.id}'),
                              left: ball.position.dx - ball.r + shake.dx,
                              top: ball.position.dy - ball.r + shake.dy,
                              child: Transform.rotate(
                                angle: ball.angle,
                                child: PlayerFaceIndicator(
                                  face: device.face,
                                  size: ball.r * 2,
                                ),
                              ),
                            );
                          }(),
                        ],
                    ],
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
