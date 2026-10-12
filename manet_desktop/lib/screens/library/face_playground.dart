import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:provider/provider.dart';

import '../../theme/app_colors.dart';
import '../../widgets/player_face_indicator.dart';
import '../home_page/gamepad_state.dart';

/// A box where players who are waiting (someone else is in the overlay
/// menu) play with their faces: round bodies with gravity that roll with the
/// stick, jump with Select (A) and can stand on top of each other.
class FacePlayground extends StatefulWidget {
  final List<String> deviceIds;

  /// Where new faces drop in; tests pass a seeded one.
  final math.Random? random;

  const FacePlayground({super.key, required this.deviceIds, this.random});

  @override
  State<FacePlayground> createState() => _FacePlaygroundState();
}

class _Ball {
  _Ball(this.id, this.position);

  final String id;
  Offset position;
  Offset velocity = Offset.zero;
  double angle = 0;
  bool grounded = false;
  bool steering = false;
}

class _FacePlaygroundState extends State<FacePlayground>
    with SingleTickerProviderStateMixin {
  static const double _radius = 34;
  static const double _gravity = 2100;
  static const double _jumpSpeed = 900;
  static const double _groundAccel = 3200;
  static const double _airAccel = 1500;
  static const double _maxSpeed = 560;
  static const double _deadZone = 0.15;
  static const int _substeps = 4;

  final Map<String, _Ball> _balls = {};
  final ValueNotifier<int> _frame = ValueNotifier(0);
  late final math.Random _random = widget.random ?? math.Random();
  late final Ticker _ticker;
  StreamSubscription<PadButtonEvent>? _buttons;
  Size _size = Size.zero;
  Duration _last = Duration.zero;

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
    if (!event.pressed || event.button != 'A') return;
    final ball = _balls[event.deviceId];
    if (ball != null && ball.grounded) {
      ball.velocity = Offset(ball.velocity.dx, -_jumpSpeed);
      ball.grounded = false;
    }
  }

  void _syncBalls() {
    _balls.removeWhere((id, _) => !widget.deviceIds.contains(id));
    for (final id in widget.deviceIds) {
      _balls.putIfAbsent(
        id,
        () => _Ball(
          id,
          Offset(
            _radius +
                _random.nextDouble() * math.max(1, _size.width - 2 * _radius),
            _radius + 4,
          ),
        ),
      );
    }
  }

  void _tick(Duration elapsed) {
    final dt = _last == Duration.zero
        ? 1 / 60
        : math.min(1 / 30, (elapsed - _last).inMicroseconds / 1e6);
    _last = elapsed;
    if (_size.isEmpty) return;
    _syncBalls();
    final gamepads = context.read<GamepadState>();
    final step = dt / _substeps;
    for (var i = 0; i < _substeps; i++) {
      _step(step, gamepads);
    }
    _frame.value++;
  }

  void _step(double dt, GamepadState gamepads) {
    final balls = _balls.values.toList();
    for (final ball in balls) {
      final stick = gamepads.inputListenable(ball.id).value.stickX;
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
      ball.angle += vx * dt / _radius;
      ball.grounded = false;
      _collideWalls(ball);
    }
    for (var a = 0; a < balls.length; a++) {
      for (var b = a + 1; b < balls.length; b++) {
        _collideBalls(balls[a], balls[b]);
      }
    }
  }

  void _collideWalls(_Ball ball) {
    var p = ball.position;
    var v = ball.velocity;
    if (p.dx < _radius) {
      p = Offset(_radius, p.dy);
      v = Offset(-v.dx * 0.4, v.dy);
    } else if (p.dx > _size.width - _radius) {
      p = Offset(_size.width - _radius, p.dy);
      v = Offset(-v.dx * 0.4, v.dy);
    }
    if (p.dy > _size.height - _radius) {
      p = Offset(p.dx, _size.height - _radius);
      v = Offset(v.dx, v.dy > 120 ? -v.dy * 0.25 : 0);
      ball.grounded = true;
    } else if (p.dy < _radius) {
      p = Offset(p.dx, _radius);
      v = Offset(v.dx, v.dy.abs() * 0.3);
    }
    ball.position = p;
    ball.velocity = v;
  }

  void _collideBalls(_Ball a, _Ball b) {
    final delta = b.position - a.position;
    final distance = delta.distance;
    const minDistance = _radius * 2;
    if (distance >= minDistance || distance == 0) return;
    final normal = delta / distance;
    final overlap = minDistance - distance;
    final _Ball? top = normal.dy < -0.55 ? b : (normal.dy > 0.55 ? a : null);

    if (top != null) {
      // Someone standing on someone: the one below acts as solid ground, so
      // the one on top neither shoves it away nor slides off while idle.
      final bottom = identical(top, b) ? a : b;
      final up = identical(top, b) ? normal : -normal; // bottom -> top
      top.position += up * overlap;
      final relative = top.velocity - bottom.velocity;
      final into = relative.dx * up.dx + relative.dy * up.dy;
      if (into < 0) top.velocity -= up * into;
      final tangent = Offset(-up.dy, up.dx);
      final along = relative.dx * tangent.dx + relative.dy * tangent.dy;
      final grip = !top.steering && up.dx.abs() < 0.5 ? 1.0 : 0.25;
      top.velocity -= tangent * (along * grip);
      top.grounded = true; // you can jump off heads
      return;
    }

    // Side by side: push apart and exchange velocity along the normal.
    a.position -= normal * (overlap / 2);
    b.position += normal * (overlap / 2);
    final relative =
        (b.velocity - a.velocity).dx * normal.dx +
        (b.velocity - a.velocity).dy * normal.dy;
    if (relative < 0) {
      final impulse = -(1 + 0.2) * relative / 2;
      a.velocity -= normal * impulse;
      b.velocity += normal * impulse;
    }
  }

  @override
  Widget build(BuildContext context) {
    final gamepads = context.watch<GamepadState>();
    return Container(
      decoration: BoxDecoration(
        color: AppColors.screenBackground.withValues(alpha: 0.92),
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: AppColors.textPrimary, width: 4),
      ),
      clipBehavior: Clip.antiAlias,
      child: LayoutBuilder(
        builder: (context, constraints) {
          _size = constraints.biggest;
          return ValueListenableBuilder<int>(
            valueListenable: _frame,
            builder: (context, _, __) => Stack(
              children: [
                for (final ball in _balls.values)
                  if (gamepads.deviceById(ball.id) case final device?)
                    Positioned(
                      left: ball.position.dx - _radius,
                      top: ball.position.dy - _radius,
                      child: Transform.rotate(
                        angle: ball.angle,
                        child: PlayerFaceIndicator(
                          face: device.face,
                          size: _radius * 2,
                        ),
                      ),
                    ),
              ],
            ),
          );
        },
      ),
    );
  }
}
