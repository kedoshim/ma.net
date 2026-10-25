import '../services/host_api_service.dart';
import 'controller_left_zone.dart';

/// The layout being edited, with the rules that tie its options together.
/// Kept apart from the editor widget so the rules can be tested on their own.
class LayoutDraft {
  static const List<String> buttons = <String>[
    'Y', 'B', 'X', 'A', 'RB', 'RT', 'LB', 'LT', 'R', 'L',
  ];
  static const List<String> rightSticks = <String>[
    'RS_FIXED', 'RS_BUTTON', 'RS_SWIPE',
  ];

  /// Buttons the right stick can hold while aiming (RT first: shooters).
  static const List<String> fireButtons = <String>[
    'RT', 'LT', 'RB', 'LB', 'A', 'B', 'X', 'Y',
  ];

  String movementMode;
  String rightLayoutMode;
  String rightStickFire;
  String rightStickFireButton;
  final Map<String, bool> visibleButtons;
  final List<String> buttonOrder;
  final Map<String, int> buttonSizes;
  final List<String> leftButtons;
  final List<String> aimButtons;
  final List<String> releaseAimButtons;

  LayoutDraft.from(ControllerPresetLayout? layout)
      : movementMode = layout?.movementMode ?? 'floatingJoystick',
        rightLayoutMode = layout?.rightLayoutMode ?? 'columns',
        rightStickFire = layout?.rightStickFire ?? 'off',
        rightStickFireButton = layout?.rightStickFireButton ?? 'RT',
        visibleButtons = <String, bool>{
          for (final id in buttons)
            id: layout?.visibleButtons[id] ?? _defaultVisible(id),
          for (final id in rightSticks)
            id: layout?.visibleButtons[id] ?? false,
        },
        buttonOrder = <String>[
          ...?layout?.buttonOrder.where(
            (id) => buttons.contains(id) || rightSticks.contains(id),
          ),
        ],
        buttonSizes = Map<String, int>.from(layout?.buttonSizes ?? const {}),
        leftButtons = List<String>.from(layout?.leftButtons ?? const []),
        aimButtons = List<String>.from(layout?.aimButtons ?? const []),
        releaseAimButtons =
            List<String>.from(layout?.releaseAimButtons ?? const []) {
    for (final id in [...buttons, ...rightSticks]) {
      if (!buttonOrder.contains(id)) buttonOrder.add(id);
    }
  }

  static bool _defaultVisible(String id) =>
      const {'LB', 'RB', 'A', 'B', 'X', 'Y'}.contains(id);

  static bool isStick(String id) => rightSticks.contains(id);

  bool isVisible(String id) => visibleButtons[id] == true;
  bool isLeft(String id) => leftButtons.contains(id);
  bool isAim(String id) => aimButtons.contains(id);
  bool isReleaseAim(String id) => releaseAimButtons.contains(id);
  bool get leftRowFull => leftButtons.length >= kLeftZoneMax;
  bool get hasRightStick => rightSticks.any(isVisible);

  /// Hiding a button also takes it out of the left row and aiming.
  void setVisible(String id, bool visible) {
    visibleButtons[id] = visible;
    if (!visible) {
      leftButtons.remove(id);
      _clearAim(id);
    }
  }

  /// Puts [id] in the left row at [slot]. A button already there swaps with
  /// it; a full row sends the one in that slot back to the right side.
  /// Aiming is a right-side thing, so the button stops aiming.
  bool moveToLeft(String id, int slot) {
    if (!isLeftZoneEligible(id)) return false;
    visibleButtons[id] = true;
    _clearAim(id);
    final from = leftButtons.indexOf(id);
    if (from != -1) {
      if (slot < leftButtons.length) {
        leftButtons[from] = leftButtons[slot];
        leftButtons[slot] = id;
      }
      return true;
    }
    if (leftRowFull) {
      final index = slot.clamp(0, leftButtons.length - 1);
      leftButtons[index] = id;
    } else {
      leftButtons.insert(slot.clamp(0, leftButtons.length), id);
    }
    return true;
  }

  /// Back on the right side (and shown), next to [target] when given.
  void moveToRight(String id, {String? target}) {
    leftButtons.remove(id);
    visibleButtons[id] = true;
    if (target == null || target == id) return;
    final from = buttonOrder.indexOf(id);
    final to = buttonOrder.indexOf(target);
    if (from == -1 || to == -1) return;
    buttonOrder[from] = target;
    buttonOrder[to] = id;
  }

  void setAim(String id, bool aim) {
    if (aim) {
      if (isLeft(id) || isStick(id) || isAim(id)) return;
      aimButtons.add(id);
    } else {
      _clearAim(id);
    }
  }

  void setReleaseAim(String id, bool release) {
    if (release) {
      if (isAim(id) && !isReleaseAim(id)) releaseAimButtons.add(id);
    } else {
      releaseAimButtons.remove(id);
    }
  }

  int sizeOf(String id) => buttonSizes[id] ?? (id == 'RS_SWIPE' ? 2 : 1);

  void _clearAim(String id) {
    aimButtons.remove(id);
    releaseAimButtons.remove(id);
  }

  ControllerPresetLayout toLayout() => ControllerPresetLayout(
        movementMode: movementMode,
        visibleButtons: Map<String, bool>.from(visibleButtons),
        buttonOrder: List<String>.from(buttonOrder),
        rightLayoutMode: rightLayoutMode,
        buttonSizes: Map<String, int>.from(buttonSizes),
        leftButtons: List<String>.from(leftButtons),
        rightStickFire: rightStickFire,
        rightStickFireButton: rightStickFireButton,
        aimButtons: List<String>.from(aimButtons),
        releaseAimButtons: List<String>.from(releaseAimButtons),
      );
}
