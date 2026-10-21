import 'controller_branding.dart';

/// The left side of the controller is movement first. The only thing it
/// takes besides the stick/D-pad is a short row of buttons on top, for games
/// that need both sticks and still a button or two under the left thumb.
/// The server applies the same rule (controller_presets.py).
const int kLeftZoneMax = 2;

const Set<String> _rightStickControls = {'RS_BUTTON', 'RS_FIXED', 'RS_SWIPE'};

bool isLeftZoneEligible(String id) {
  final canonical = ControllerBranding.normalizeCanonicalId(id);
  return ControllerBranding.isSupportedCanonicalId(canonical) &&
      !_rightStickControls.contains(canonical);
}

List<String> normalizeLeftButtons(Iterable<dynamic> raw) {
  final result = <String>[];
  for (final item in raw) {
    final canonical = ControllerBranding.normalizeCanonicalId('$item');
    if (isLeftZoneEligible(canonical) && !result.contains(canonical)) {
      result.add(canonical);
    }
    if (result.length == kLeftZoneMax) break;
  }
  return result;
}
