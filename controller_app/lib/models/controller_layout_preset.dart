import '../services/preferences_service.dart';

class ControllerLayoutPreset {
  const ControllerLayoutPreset({
    required this.id,
    required this.name,
    required this.movementMode,
    required this.visibleButtons,
    required this.buttonOrder,
  });

  final String id;
  final String name;
  final MovementMode movementMode;
  final Map<String, bool> visibleButtons;
  final List<String> buttonOrder;

  factory ControllerLayoutPreset.fromJson(Map<String, dynamic> json) {
    final layout = json['layout'] as Map<String, dynamic>? ?? json;
    final rawVisibility =
        layout['visibleButtons'] as Map<String, dynamic>? ??
        const <String, dynamic>{};
    final rawOrder = layout['buttonOrder'] as List<dynamic>? ?? const [];

    return ControllerLayoutPreset(
      id: json['id'] as String? ?? 'preset-remoto',
      name: json['name'] as String? ?? 'Preset remoto',
      movementMode: movementModeFromWire(
        layout['movementMode'] as String?,
      ),
      visibleButtons: rawVisibility.map(
        (key, value) => MapEntry(key, value == true),
      ),
      buttonOrder: rawOrder.map((item) => '$item').toList(),
    );
  }
}
