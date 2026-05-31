import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../models/player_face.dart';
import '../theme/app_colors.dart';

class PlayerFaceIndicator extends StatefulWidget {
  final PlayerFaceData face;
  final double size;
  final bool roundedSquare;
  final double scale;
  final double opacity;
  final double translateX;
  final double translateY;
  final double faceTranslateX;
  final double faceTranslateY;
  final bool pressed;
  final Color? borderColor;

  const PlayerFaceIndicator({
    super.key,
    required this.face,
    required this.size,
    this.roundedSquare = false,
    this.scale = 1,
    this.opacity = 1,
    this.translateX = 0,
    this.translateY = 0,
    this.faceTranslateX = 0,
    this.faceTranslateY = 0,
    this.pressed = false,
    this.borderColor,
  });

  @override
  State<PlayerFaceIndicator> createState() => _PlayerFaceIndicatorState();
}

class _PlayerFaceIndicatorState extends State<PlayerFaceIndicator>
    with TickerProviderStateMixin {
  late AnimationController _squishController;
  late AnimationController _popController;

  double _capturedSquishAmount = 0.0;

  @override
  void initState() {
    super.initState();
    _squishController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _squishController.addListener(() => setState(() {}));

    _popController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    );
    _popController.addListener(() => setState(() {}));

    if (widget.pressed) {
      _squishController.forward();
    }
  }

  @override
  void didUpdateWidget(covariant PlayerFaceIndicator oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.pressed && !oldWidget.pressed) {
      _popController.stop();
      _squishController.forward(from: 0.0);
    } else if (!widget.pressed && oldWidget.pressed) {
      _capturedSquishAmount = Curves.easeOutCubic.transform(
        _squishController.value,
      );
      _squishController.stop();
      _squishController.value = 0.0;
      _popController.forward(from: 0.0);
    }
  }

  @override
  void dispose() {
    _squishController.dispose();
    _popController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final borderRadius = widget.roundedSquare
        ? BorderRadius.circular(widget.size * 0.24)
        : BorderRadius.circular(widget.size);

    double scaleModifier = 1.0;

    if (widget.pressed) {
      final squishAmount = Curves.easeOutCubic.transform(
        _squishController.value,
      );
      // Max squish reduces scale by up to 45%
      scaleModifier = 1.0 - (squishAmount * 0.45);
    } else if (_popController.isAnimating) {
      final startScale = 1.0 - (_capturedSquishAmount * 0.45);
      // The more it squished, the bigger the peak expansion
      final peakScale = 1.0 + 0.10 + (_capturedSquishAmount * 0.45);

      if (_popController.value < 0.1) {
        // Phase 1: Fast explosive expansion (first 10% of duration)
        final t = _popController.value / 0.1;
        scaleModifier =
            startScale +
            (peakScale - startScale) * Curves.easeOutCubic.transform(t);
      } else {
        // Phase 2: Slow elastic settle back to normal (last 90% of duration)
        final t = (_popController.value - 0.1) / 0.9;
        scaleModifier =
            peakScale - (peakScale - 1.0) * Curves.elasticOut.transform(t);
      }
    }

    final finalScale = widget.scale * scaleModifier;

    return Opacity(
      opacity: widget.opacity,
      child: Transform.scale(
        scale: finalScale,
        child: Transform.translate(
          offset: Offset(widget.translateX, widget.translateY),
          child: Container(
            width: widget.size,
            height: widget.size,
            decoration: BoxDecoration(
              color: widget.face.color,
              borderRadius: borderRadius,
              border: Border.all(
                color: widget.borderColor ?? AppColors.textPrimary,
                width: math.max(1.5, widget.size * 0.04),
              ),
            ),
            child: Center(
              child: Padding(
                padding: EdgeInsets.symmetric(
                  horizontal: widget.size * 0.12,
                  vertical: widget.size * 0.14,
                ),
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Transform.translate(
                    offset: Offset(
                      widget.faceTranslateX,
                      widget.faceTranslateY,
                    ),
                    child: Transform.rotate(
                      angle: playerFaceRotationAngle(widget.face.rotation),
                      child: Text(
                        widget.face.faceText,
                        maxLines: 1,
                        softWrap: false,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontFamily: 'monomaniac',
                          fontFamilyFallback: const ['noto_symbols'],
                          fontSize: widget.size * 0.7,
                          height: 0.9,
                          color: Colors.black.withValues(alpha: 0.8),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
