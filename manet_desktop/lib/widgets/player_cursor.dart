import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/player_face.dart';
import '../screens/home_page/gamepad_state.dart';
import '../services/host_api_service.dart';
import '../theme/app_colors.dart';
import 'comic_burst.dart';

/// A player's pointer on MaNet's menus: one rounded arrowhead (no stem) in
/// the player's color with their face inside and their name under it.
///
/// The widget is [size]×[size] and the arrow's tip sits at its center, so
/// callers position it with `point - size / 2` (the arrow and the name tag
/// overflow to the bottom right).
class PlayerCursor extends StatelessWidget {
  final DeviceModel device;
  final double size;
  final int bopTrigger;

  /// Bumped when the player presses the emote button: the arrow wiggles.
  final int emoteTrigger;

  /// The player is reading a game's details on their phone.
  final bool reading;
  final bool showName;

  const PlayerCursor({
    super.key,
    required this.device,
    required this.size,
    this.bopTrigger = 0,
    this.emoteTrigger = 0,
    this.reading = false,
    this.showName = true,
  });

  @override
  Widget build(BuildContext context) {
    final gamepads = context.read<GamepadState>();
    final arrow = size * 1.35;

    return ValueListenableBuilder<DeviceInputState>(
      valueListenable: gamepads.inputListenable(device.id),
      builder: (context, input, _) {
        final stickX = -input.stickX;
        final stickY = -input.stickY;
        final isCentered = stickX == 0.0 && stickY == 0.0;
        final pressed = input.buttonPressed;
        // The face leans a little the way the stick pushes.
        final lean = Offset(stickX, stickY) * (size * 0.05);

        return SizedBox(
          width: size,
          height: size,
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              Positioned(
                left: size / 2,
                top: size / 2,
                child: EmoteWiggle(
                  trigger: emoteTrigger,
                  child: ComicBopBurst(
                    trigger: bopTrigger,
                    burstColor: device.color,
                    burstRadius: size * 0.55,
                    child: AnimatedScale(
                      scale: pressed ? 0.88 : 1,
                      alignment: Alignment.topLeft,
                      duration: const Duration(milliseconds: 90),
                      child: TweenAnimationBuilder<Offset>(
                        tween: Tween(begin: lean, end: lean),
                        duration: Duration(milliseconds: isCentered ? 320 : 80),
                        curve: isCentered
                            ? Curves.elasticOut
                            : Curves.easeOutQuad,
                        builder: (context, offset, _) => CursorArrow(
                          face: device.face,
                          size: arrow,
                          faceOffset: offset,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              if (reading)
                Positioned(
                  left: size / 2 + arrow * 0.6,
                  top: size / 2 + arrow * 0.05,
                  child: const _InfoBadge(),
                ),
              if (showName && device.name.isNotEmpty)
                Positioned(
                  left: size / 2 + arrow * 0.08,
                  top: size / 2 + arrow * 1.04,
                  child: _NameTag(name: device.name),
                ),
            ],
          ),
        );
      },
    );
  }
}

/// The arrowhead shape with the face inside, tip at the top-left corner.
class CursorArrow extends StatelessWidget {
  final PlayerFaceData face;
  final double size;
  final Offset faceOffset;

  const CursorArrow({
    super.key,
    required this.face,
    required this.size,
    this.faceOffset = Offset.zero,
  });

  @override
  Widget build(BuildContext context) {
    final faceBox = size * 0.4;
    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(
        painter: _ArrowPainter(color: face.color),
        child: Stack(
          children: [
            Positioned(
              left: size * 0.34 - faceBox / 2 + faceOffset.dx,
              top: size * 0.5 - faceBox / 2 + faceOffset.dy,
              width: faceBox,
              height: faceBox,
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Transform.rotate(
                  angle: playerFaceRotationAngle(face.rotation),
                  child: Text(
                    face.faceText,
                    maxLines: 1,
                    softWrap: false,
                    style: TextStyle(
                      fontFamily: 'monomaniac',
                      fontFamilyFallback: const ['noto_symbols'],
                      fontSize: faceBox * 0.8,
                      height: 0.9,
                      color: Colors.black.withValues(alpha: 0.85),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Rounded arrowhead: a sharp tip at (0, 0), straight sides and a round back.
/// The classic pointer: tip, right corner, a notch cut into the back and the
/// bottom corner, every corner rounded.
Path cursorArrowPath(Size size) {
  const corners = [
    // (x, y, rounding) as fractions of the box.
    (0.0, 0.0, 0.10), // tip
    (0.88, 0.60, 0.12), // right
    (0.47, 0.71, 0.14), // notch (the inset in the back)
    (0.10, 1.0, 0.12), // bottom
  ];
  final points = [
    for (final (x, y, _) in corners) Offset(x * size.width, y * size.height),
  ];
  final path = Path();
  for (var i = 0; i < points.length; i++) {
    final point = points[i];
    final previous = points[(i - 1 + points.length) % points.length];
    final next = points[(i + 1) % points.length];
    final radius = corners[i].$3 * size.width;
    Offset toward(Offset other) {
      final d = other - point;
      return point + d / d.distance * math.min(radius, d.distance / 2);
    }

    final start = toward(previous);
    final end = toward(next);
    if (i == 0) {
      path.moveTo(start.dx, start.dy);
    } else {
      path.lineTo(start.dx, start.dy);
    }
    path.quadraticBezierTo(point.dx, point.dy, end.dx, end.dy);
  }
  return path..close();
}

class _ArrowPainter extends CustomPainter {
  final Color color;

  const _ArrowPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final path = cursorArrowPath(size);
    final stroke = math.max(3.0, size.width * 0.07);
    canvas.drawShadow(path, Colors.black, 4, false);
    canvas.drawPath(path, Paint()..color = color);
    canvas.drawPath(
      path,
      Paint()
        ..color = AppColors.textPrimary
        ..style = PaintingStyle.stroke
        ..strokeWidth = stroke
        ..strokeJoin = StrokeJoin.round,
    );
  }

  @override
  bool shouldRepaint(covariant _ArrowPainter oldDelegate) =>
      oldDelegate.color != color;
}

class _NameTag extends StatelessWidget {
  final String name;

  const _NameTag({required this.name});

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(maxWidth: 140),
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
      decoration: BoxDecoration(
        color: AppColors.textPrimary,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        name,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(
          fontFamily: 'momo',
          fontWeight: FontWeight.bold,
          fontSize: 12,
          color: Colors.white,
        ),
      ),
    );
  }
}

class _InfoBadge extends StatelessWidget {
  const _InfoBadge();

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.3, end: 1),
      duration: const Duration(milliseconds: 420),
      curve: Curves.elasticOut,
      builder: (context, scale, child) =>
          Transform.scale(scale: scale, child: child),
      child: Container(
        width: 24,
        height: 24,
        decoration: BoxDecoration(
          color: AppColors.lightColor,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: AppColors.textPrimary, width: 2.5),
        ),
        child: const Icon(
          Icons.info_outline_rounded,
          size: 16,
          color: AppColors.textPrimary,
        ),
      ),
    );
  }
}

/// Shakes and hops its child for a moment every time [trigger] changes
/// (a player's emote button).
class EmoteWiggle extends StatefulWidget {
  final int trigger;
  final Alignment alignment;
  final Widget child;

  const EmoteWiggle({
    super.key,
    required this.trigger,
    required this.child,
    this.alignment = Alignment.topLeft,
  });

  @override
  State<EmoteWiggle> createState() => EmoteWiggleState();
}

class EmoteWiggleState extends State<EmoteWiggle>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 650),
  );

  @override
  void didUpdateWidget(covariant EmoteWiggle oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.trigger != oldWidget.trigger) _controller.forward(from: 0);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      child: widget.child,
      builder: (context, child) {
        final t = _controller.value;
        final fade = 1 - t;
        final angle = math.sin(t * math.pi * 6) * 0.35 * fade;
        final hop = -math.sin(t * math.pi) * 10;
        return Transform.translate(
          offset: Offset(0, hop),
          child: Transform.rotate(
            angle: angle,
            alignment: widget.alignment,
            child: Transform.scale(
              scale: 1 + 0.15 * math.sin(t * math.pi),
              alignment: widget.alignment,
              child: child,
            ),
          ),
        );
      },
    );
  }
}
