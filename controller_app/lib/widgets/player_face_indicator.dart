import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../models/player_face.dart';

class PlayerFaceIndicator extends StatelessWidget {
  final PlayerFaceData face;
  final double size;
  final bool roundedSquare;
  final double scale;
  final double opacity;
  final double translateX;
  final double translateY;
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
    this.pressed = false,
    this.borderColor,
  });

  @override
  Widget build(BuildContext context) {
    final borderRadius = roundedSquare
        ? BorderRadius.circular(size * 0.24)
        : BorderRadius.circular(size);

    return Opacity(
      opacity: opacity,
      child: AnimatedScale(
        scale: pressed ? scale * 0.82 : scale,
        duration: Duration(milliseconds: pressed ? 60 : 240),
        curve: pressed ? Curves.easeOut : Curves.elasticOut,
        child: Transform.translate(
          offset: Offset(translateX, translateY),
          child: Container(
            width: size,
            height: size,
            decoration: BoxDecoration(
              color: face.color,
              borderRadius: borderRadius,
              border: borderColor != null
                  ? Border.all(
                      color: borderColor!,
                      width: math.max(1.5, size * 0.04),
                    )
                  : null,
            ),
            child: Center(
              child: Padding(
                padding: EdgeInsets.symmetric(
                  horizontal: size * 0.12,
                  vertical: size * 0.14,
                ),
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Transform.rotate(
                    angle: _rotationAngle(face.rotation),
                    child: Text(
                      face.faceText,
                      maxLines: 1,
                      softWrap: false,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontFamily: 'monomaniac',
                        fontSize: size * 0.7,
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
