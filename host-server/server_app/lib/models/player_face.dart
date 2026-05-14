import 'dart:math' as math;

import 'package:flutter/material.dart';

enum PlayerFaceRotation { normal, upsideDown, leftVertical, rightVertical }

PlayerFaceRotation playerFaceRotationFromWire(String? value) {
  switch (value) {
    case 'upside_down':
      return PlayerFaceRotation.upsideDown;
    case 'left_vertical':
      return PlayerFaceRotation.leftVertical;
    case 'right_vertical':
      return PlayerFaceRotation.rightVertical;
    case 'normal':
    default:
      return PlayerFaceRotation.normal;
  }
}

class PlayerFaceData {
  final Color color;
  final String faceText;
  final PlayerFaceRotation rotation;
  final String? presetId;

  const PlayerFaceData({
    required this.color,
    required this.faceText,
    required this.rotation,
    this.presetId,
  });

  factory PlayerFaceData.fromJson(
    Map<String, dynamic> json, {
    Color? fallbackColor,
  }) {
    final faceText = (json['faceText'] as String?)?.trim();
    return PlayerFaceData(
      color: json['color'] != null
          ? colorFromHex(json['color'] as String)
          : (fallbackColor ?? Colors.white),
      faceText: _sanitizeFaceText(faceText),
      rotation: playerFaceRotationFromWire(json['faceRotation'] as String?),
      presetId: json['presetId'] as String?,
    );
  }
}

Color colorFromHex(String hex) {
  final cleaned = hex.replaceAll('#', '');
  return Color(int.parse('FF$cleaned', radix: 16));
}

String _sanitizeFaceText(String? input) {
  if (input == null) {
    return ':)';
  }
  final runes = input
      .replaceAll(RegExp(r'[\r\n\t]+'), '')
      .runes
      .take(3)
      .toList();
  return String.fromCharCodes(runes);
}

double playerFaceRotationAngle(PlayerFaceRotation rotation) {
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
