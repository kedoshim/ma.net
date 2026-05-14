import 'dart:math';

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

String playerFaceRotationToWire(PlayerFaceRotation rotation) {
  switch (rotation) {
    case PlayerFaceRotation.upsideDown:
      return 'upside_down';
    case PlayerFaceRotation.leftVertical:
      return 'left_vertical';
    case PlayerFaceRotation.rightVertical:
      return 'right_vertical';
    case PlayerFaceRotation.normal:
      return 'normal';
  }
}

String sanitizeFaceText(String input) {
  final flattened = input.replaceAll(RegExp(r'[\r\n\t]+'), '');
  final runes = flattened.runes.take(3).toList();
  if (runes.isEmpty) {
    return '';
  }
  return String.fromCharCodes(runes);
}

Color colorFromHex(String hex) {
  final cleaned = hex.replaceAll('#', '');
  return Color(int.parse('FF$cleaned', radix: 16));
}

String colorToHex(Color color) {
  final rgb = color.toARGB32() & 0xFFFFFF;
  return '#${rgb.toRadixString(16).padLeft(6, '0').toUpperCase()}';
}

class PlayerFacePreset {
  final String id;
  final String label;
  final String faceText;
  final PlayerFaceRotation rotation;
  final Color color;

  const PlayerFacePreset({
    required this.id,
    required this.label,
    required this.faceText,
    required this.rotation,
    required this.color,
  });
}

const List<Color> playerFacePalette = [
  Color(0xFFFF6B6B),
  Color(0xFFFFA94D),
  Color(0xFFFFE066),
  Color(0xFF8CE99A),
  Color(0xFF66D9E8),
  Color(0xFF74C0FC),
  Color(0xFFA78BFA),
  Color(0xFFF783AC),
];

const List<PlayerFacePreset> playerFacePresets = [
  PlayerFacePreset(
    id: 'happy',
    label: 'happy',
    faceText: ':)',
    rotation: PlayerFaceRotation.normal,
    color: Color(0xFFFFE066),
  ),
  PlayerFacePreset(
    id: 'angry',
    label: 'angry',
    faceText: '>:(',
    rotation: PlayerFaceRotation.normal,
    color: Color(0xFFFF6B6B),
  ),
  PlayerFacePreset(
    id: 'confused',
    label: 'confused',
    faceText: ':/',
    rotation: PlayerFaceRotation.rightVertical,
    color: Color(0xFF74C0FC),
  ),
  PlayerFacePreset(
    id: 'silly',
    label: 'silly',
    faceText: ':P',
    rotation: PlayerFaceRotation.normal,
    color: Color(0xFF8CE99A),
  ),
  PlayerFacePreset(
    id: 'deadpan',
    label: 'deadpan',
    faceText: '-_-',
    rotation: PlayerFaceRotation.normal,
    color: Color(0xFFA78BFA),
  ),
  PlayerFacePreset(
    id: 'cursed',
    label: 'cursed',
    faceText: 'OwO',
    rotation: PlayerFaceRotation.upsideDown,
    color: Color(0xFFF783AC),
  ),
];

PlayerFacePreset? playerFacePresetById(String? id) {
  if (id == null) {
    return null;
  }
  for (final preset in playerFacePresets) {
    if (preset.id == id) {
      return preset;
    }
  }
  return null;
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

  factory PlayerFaceData.fromJson(Map<String, dynamic> json) {
    return PlayerFaceData(
      color: json['color'] != null
          ? colorFromHex(json['color'] as String)
          : playerFacePalette.first,
      faceText: sanitizeFaceText((json['faceText'] as String?) ?? ''),
      rotation: playerFaceRotationFromWire(json['faceRotation'] as String?),
      presetId: json['presetId'] as String?,
    );
  }

  factory PlayerFaceData.random([Random? random]) {
    final rng = random ?? Random();
    final preset = playerFacePresets[rng.nextInt(playerFacePresets.length)];
    final color = playerFacePalette[rng.nextInt(playerFacePalette.length)];
    return PlayerFaceData(
      color: color,
      faceText: preset.faceText,
      rotation: preset.rotation,
      presetId: preset.id,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'color': colorToHex(color),
      'faceText': sanitizeFaceText(faceText),
      'faceRotation': playerFaceRotationToWire(rotation),
      'presetId': presetId,
    };
  }

  PlayerFaceData copyWith({
    Color? color,
    String? faceText,
    PlayerFaceRotation? rotation,
    String? presetId,
    bool clearPreset = false,
  }) {
    return PlayerFaceData(
      color: color ?? this.color,
      faceText: sanitizeFaceText(faceText ?? this.faceText),
      rotation: rotation ?? this.rotation,
      presetId: clearPreset ? null : (presetId ?? this.presetId),
    );
  }

  PlayerFaceData applyPreset(PlayerFacePreset preset) {
    return PlayerFaceData(
      color: preset.color,
      faceText: preset.faceText,
      rotation: preset.rotation,
      presetId: preset.id,
    );
  }
}
