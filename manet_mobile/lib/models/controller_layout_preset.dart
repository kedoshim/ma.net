import '../models/controller_branding.dart';
import '../services/preferences_service.dart';

class ControllerLayoutPreset {
  const ControllerLayoutPreset({
    required this.id,
    required this.name,
    required this.movementMode,
    required this.visibleButtons,
    required this.buttonOrder,
    required this.buttonSizes,
    required this.rightLayoutMode,
  });

  final String id;
  final String name;
  final MovementMode movementMode;
  final Map<String, bool> visibleButtons;
  final List<String> buttonOrder;
  final Map<String, int> buttonSizes;
  final String rightLayoutMode;

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
    );
  }
}
