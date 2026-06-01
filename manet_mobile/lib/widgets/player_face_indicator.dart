import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../models/player_face.dart';

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
    with SingleTickerProviderStateMixin {
  late AnimationController _wobbleController;
  late Animation<double> _wobbleAnimation;

  @override
  void initState() {
    super.initState();
    _wobbleController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 450),
    );
    _wobbleAnimation = TweenSequence<double>([
      TweenSequenceItem(
        tween: Tween<double>(begin: 0.0, end: -0.12)
            .chain(CurveTween(curve: Curves.easeOutCubic)),
        weight: 20.0,
      ),
      TweenSequenceItem(
        tween: Tween<double>(begin: -0.12, end: 0.10)
            .chain(CurveTween(curve: Curves.easeInOutCubic)),
        weight: 30.0,
      ),
      TweenSequenceItem(
        tween: Tween<double>(begin: 0.10, end: -0.05)
            .chain(CurveTween(curve: Curves.easeInOutCubic)),
        weight: 25.0,
      ),
      TweenSequenceItem(
        tween: Tween<double>(begin: -0.05, end: 0.0)
            .chain(CurveTween(curve: Curves.easeInCubic)),
        weight: 25.0,
      ),
    ]).animate(_wobbleController);
    _wobbleController.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _wobbleController.dispose();
    super.dispose();
  }

  void _handlePointerDown(PointerDownEvent event) {
    if (!_wobbleController.isAnimating) {
      _wobbleController.forward(from: 0.0);
    }
  }

  @override
  Widget build(BuildContext context) {
    final borderRadius = widget.roundedSquare
        ? BorderRadius.circular(widget.size * 0.24)
        : BorderRadius.circular(widget.size);

    return Listener(
      onPointerDown: _handlePointerDown,
      child: Opacity(
        opacity: widget.opacity,
        child: AnimatedScale(
          scale: widget.pressed ? widget.scale * 0.82 : widget.scale,
          duration: Duration(milliseconds: widget.pressed ? 60 : 240),
          curve: widget.pressed ? Curves.easeOut : Curves.elasticOut,
          child: Transform.rotate(
            angle: _wobbleAnimation.value,
            child: Transform.translate(
              offset: Offset(widget.translateX, widget.translateY),
              child: Container(
                width: widget.size,
                height: widget.size,
                decoration: BoxDecoration(
                  color: widget.face.color,
                  borderRadius: borderRadius,
                  border: widget.borderColor != null
                      ? Border.all(
                          color: widget.borderColor!,
                          width: math.max(1.5, widget.size * 0.04),
                        )
                      : null,
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
                        offset: Offset(widget.faceTranslateX, widget.faceTranslateY),
                        child: Transform.rotate(
                          angle: _rotationAngle(widget.face.rotation),
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
        ),
      ),
    );
  }
}

double _rotationAngle(PlayerFaceRotation rotation) {
  switch (rotation) {
    case PlayerFaceRotation.upsideDown:
      return math.pi;
    case PlayerFaceRotation.leftVertical:
      return -math.pi / 2;
    case PlayerFaceRotation.rightVertical:
      return math.pi / 2;
    case PlayerFaceRotation.normal:
      return 0;
  }
}
