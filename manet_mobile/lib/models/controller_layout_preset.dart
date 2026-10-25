import '../models/controller_branding.dart';
import '../models/controller_left_zone.dart';
import '../services/preferences_service.dart';
import '../widgets/right_stick_controls.dart';

class ControllerLayoutPreset {
  const ControllerLayoutPreset({
    required this.id,
    required this.name,
    required this.movementMode,
    required this.visibleButtons,
    required this.buttonOrder,
    required this.buttonSizes,
    required this.rightLayoutMode,
    this.leftButtons = const [],
    this.aimButtons = const [],
    this.releaseAimButtons = const [],
    this.rightStickFire = kFireOff,
    this.rightStickFireButton = 'RT',
  });

  final String id;
  final String name;
  final MovementMode movementMode;
  final Map<String, bool> visibleButtons;
  final List<String> buttonOrder;
  final Map<String, int> buttonSizes;
  final String rightLayoutMode;
  final List<String> leftButtons;
  /// Right-side buttons that also aim with the right stick when dragged.
  final List<String> aimButtons;
  /// Aim buttons that press only when the finger lifts.
  final List<String> releaseAimButtons;
  /// Aim-and-fire the game asks for ('off', 'touch' or 'ring').
  final String rightStickFire;
  final String rightStickFireButton;

  factory ControllerLayoutPreset.fromJson(Map<String, dynamic> json) {
    final layout = json['layout'] as Map<String, dynamic>? ?? json;
    final rawVisibility =
        layout['visibleButtons'] as Map<String, dynamic>? ??
        const <String, dynamic>{};
    final rawOrder = layout['buttonOrder'] as List<dynamic>? ?? const [];
    final rawSizes = layout['buttonSizes'] as Map<String, dynamic>? ??
        const <String, dynamic>{};

    final Map<String, int> parsedSizes = {};
    rawSizes.forEach((key, value) {
      if (value is num) {
        parsedSizes[ControllerBranding.normalizeCanonicalId(key)] = value.toInt();
      }
    });

    final aimButtons = normalizeAimButtons(
      layout['aimButtons'] as List<dynamic>? ?? const [],
    );

    return ControllerLayoutPreset(
      id: json['id'] as String? ?? 'preset-remoto',
      name: json['name'] as String? ?? 'Preset remoto',
      movementMode: movementModeFromWire(
        layout['movementMode'] as String?,
      ),
      visibleButtons: ControllerBranding.normalizeVisibility(rawVisibility),
      buttonOrder: ControllerBranding.normalizeCanonicalOrder(rawOrder),
      buttonSizes: parsedSizes,
      rightLayoutMode: layout['rightLayoutMode'] as String? ?? 'columns',
      leftButtons: normalizeLeftButtons(
        layout['leftButtons'] as List<dynamic>? ?? const [],
      ),
      rightStickFire: normalizeFireMode(layout['rightStickFire']),
      aimButtons: aimButtons,
      releaseAimButtons: normalizeReleaseAimButtons(
        layout['releaseAimButtons'] as List<dynamic>? ?? const [],
        aimButtons,
      ),
      rightStickFireButton: normalizeFireButton(layout['rightStickFireButton']),
    );
  }
}
