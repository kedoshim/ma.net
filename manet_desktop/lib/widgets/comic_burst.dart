import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../services/sound_effect_service.dart';
import '../theme/app_colors.dart';

/// Reusable cartoon pop effect: radiating sunburst rays ("sol desenhado por criança")
/// and dynamic bop (squash & stretch hop) for mascots, buttons, and countdowns.
class ComicBopBurst extends StatefulWidget {
  final Widget? child;
  final Color? burstColor;
  final int trigger;
  final double burstRadius;
  final int rayCount;
  final double rayWidth;
  final bool enableHop;
  final bool playSound;
  final bool showDots;
  final Duration duration;

  const ComicBopBurst({
    super.key,
    this.child,
    this.burstColor,
    this.trigger = 0,
    this.burstRadius = 36.0,
    this.rayCount = 8,
    this.rayWidth = 3.5,
    this.enableHop = true,
    this.playSound = false,
    this.showDots = true,
    this.duration = const Duration(milliseconds: 460),
  });

  @override
  State<ComicBopBurst> createState() => _ComicBopBurstState();
}

class _ComicBopBurstState extends State<ComicBopBurst>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: widget.duration,
    );
  }

  @override
  void didUpdateWidget(covariant ComicBopBurst oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.trigger != oldWidget.trigger && widget.trigger > 0) {
      _controller.forward(from: 0.0);
      if (widget.playSound) {
        try {
          SoundEffectService.instance.playPlayerJoinPop();
        } catch (_) {}
      }
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final color = widget.burstColor ?? AppColors.highlightColor;

    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        final t = _controller.value;
        final isAnimating = _controller.isAnimating;

        double scaleX = 1.0;
        double scaleY = 1.0;
        double translateY = 0.0;

        if (widget.enableHop && isAnimating) {
          if (t < 0.15) {
            // Phase 1: Squash anticipation
            final p = t / 0.15;
            scaleX = 1.0 + (p * 0.14);
            scaleY = 1.0 - (p * 0.14);
            translateY = p * 2.0;
          } else if (t < 0.45) {
            // Phase 2: Upward hop & stretch
            final p = (t - 0.15) / 0.30;
            final hopCurve = Curves.easeOutCubic.transform(p);
            translateY = 2.0 - (10.0 * hopCurve);
            scaleX = 1.14 - (0.24 * hopCurve);
            scaleY = 0.86 + (0.32 * hopCurve);
          } else {
            // Phase 3: Elastic settle bounce
            final p = (t - 0.45) / 0.55;
            final spring = math.sin(p * math.pi * 3.0) * (1.0 - p) * 0.12;
            scaleX = 1.0 - spring;
            scaleY = 1.0 + spring;
            translateY = -8.0 * (1.0 - Curves.easeOutBack.transform(p.clamp(0.0, 1.0)));
          }
        }

        Widget content = widget.child ?? const SizedBox.shrink();
        if (widget.enableHop) {
          content = Transform.translate(
            offset: Offset(0.0, translateY),
            child: Transform.scale(
              scaleX: scaleX,
              scaleY: scaleY,
              alignment: Alignment.center,
              child: content,
            ),
          );
        }

        return CustomPaint(
          foregroundPainter: isAnimating
              ? ComicBurstPainter(
                  progress: t,
                  color: color,
                  baseRadius: widget.burstRadius,
                  rayCount: widget.rayCount,
                  rayWidth: widget.rayWidth,
                  showDots: widget.showDots,
                )
              : null,
          child: content,
        );
      },
    );
  }
}

/// CustomPainter for radiating cartoon pop lines like a kid-drawn sun.
class ComicBurstPainter extends CustomPainter {
  final double progress; // 0.0 to 1.0
  final Color color;
  final double baseRadius;
  final int rayCount;
  final double rayWidth;
  final bool showDots;

  ComicBurstPainter({
    required this.progress,
    required this.color,
    required this.baseRadius,
    this.rayCount = 8,
    this.rayWidth = 3.5,
    this.showDots = true,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (progress <= 0 || progress >= 1.0) return;

    final center = Offset(size.width / 2, size.height / 2);

    // Fast explosive shoot out, followed by inner catch-up
    final shoot = Curves.easeOutCubic.transform(progress);
    final catchUp = Curves.easeInCubic.transform(progress);
    final alpha = (1.0 - Curves.easeInQuad.transform(progress)).clamp(0.0, 1.0);

    final maxReach = baseRadius * 1.85;
    final rInner = baseRadius + (maxReach - baseRadius) * catchUp;
    final rOuter = baseRadius + (maxReach - baseRadius) * shoot + 5.0;

    final rayPaint = Paint()
      ..color = color.withValues(alpha: alpha)
      ..strokeWidth = (rayWidth * (1.0 - progress * 0.3)).clamp(1.5, 10.0)
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;

    final dotPaint = Paint()
      ..color = color.withValues(alpha: alpha)
      ..style = PaintingStyle.fill;

    final angleStep = (2 * math.pi) / rayCount;

    for (int i = 0; i < rayCount; i++) {
      final angle = i * angleStep;
      final cosA = math.cos(angle);
      final sinA = math.sin(angle);

      // Radiating line (sun ray pointing to center)
      if (rOuter > rInner) {
        final p1 = Offset(center.dx + cosA * rInner, center.dy + sinA * rInner);
        final p2 = Offset(center.dx + cosA * rOuter, center.dy + sinA * rOuter);
        canvas.drawLine(p1, p2, rayPaint);
      }

      // Small secondary pop dot placed halfway between rays
      if (showDots) {
        final dotAngle = angle + (angleStep / 2);
        final dotDist = baseRadius + (maxReach * 0.85 - baseRadius) * shoot + 3.0;
        final dotSize = (rayWidth * 0.85) * (1.0 - progress * 0.45);
        if (dotSize > 0.5) {
          canvas.drawCircle(
            Offset(center.dx + math.cos(dotAngle) * dotDist,
                center.dy + math.sin(dotAngle) * dotDist),
            dotSize,
            dotPaint,
          );
        }
      }
    }
  }

  @override
  bool shouldRepaint(covariant ComicBurstPainter oldDelegate) {
    return oldDelegate.progress != progress ||
        oldDelegate.color != color ||
        oldDelegate.baseRadius != baseRadius;
  }
}
