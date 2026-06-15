import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/gestures.dart';
import '../services/haptics_manager.dart';
import '../services/preferences_service.dart';
import '../widgets/right_stick_controls.dart';

const bool kNormalizeJoystickInCircle = false;

typedef CoordinateConverter = Offset Function(Offset globalPosition);

class ActiveControlState {
  final int pointerId;
  final String controlId;
  final int controlHashCode;
  final ValueNotifier<Offset> visualOffset;
  final ValueNotifier<bool> active;
  final ValueNotifier<Offset> basePos;
  final CoordinateConverter converter;
  final Offset Function(Offset localPos)? clampBase;
  final double baseSize;

  ActiveControlState({
    required this.pointerId,
    required this.controlId,
    required this.controlHashCode,
    required this.visualOffset,
    required this.active,
    required this.basePos,
    required this.converter,
    this.clampBase,
    required this.baseSize,
  });
}

class GamepadInputEngine {
  static final GamepadInputEngine instance = GamepadInputEngine._();
  GamepadInputEngine._();

  // Active control states (holds visual notifiers and converters unique to the active widget instance)
  ActiveControlState? _activeLeft;
  ActiveControlState? _activeRight;

  // WebSocket sending interface
  void Function(Map<String, dynamic> payload)? _sendFn;
  Ticker? _ticker;
  Duration _lastTickElapsed = Duration.zero;

  // Left Joystick configuration/state
  MovementMode _leftMode = MovementMode.fixedJoystick;
  double _leftSensitivity = 1.0;
  Size _leftSize = Size.zero;

  // Right Joystick configuration/state
  String _rightLayout = 'RS_FIXED'; // 'RS_BUTTON' (floating), 'RS_FIXED', 'RS_SWIPE'
  RightStickConfig _rightConfig = const RightStickConfig();
  Size _rightSize = Size.zero;

  // Touch coordinates (local to control bounds)
  Offset _leftTouchCurrent = Offset.zero;
  Offset _leftBaseLocal = Offset.zero;

  Offset _rightTouchCurrent = Offset.zero;
  Offset _rightBaseLocal = Offset.zero;

  // Global coordinates (kept only for diagnostic logging)
  Offset _leftTouchCurrentGlobal = Offset.zero;
  Offset _rightTouchCurrentGlobal = Offset.zero;

  // Stick output values (-1.0 to 1.0)
  double _leftX = 0.0;
  double _leftY = 0.0;
  double _rightX = 0.0;
  double _rightY = 0.0;

  // Swipe Pad state variables
  Offset _swipeLastTickPos = Offset.zero;
  Offset _swipeCurrentPos = Offset.zero;
  bool _swipeHasMovedThisTick = false;
  double _swipeStickX = 0.0;
  double _swipeStickY = 0.0;

  // Zero send trackers for clean releases
  int _leftZeroSendsLeft = 0;
  int _rightZeroSendsLeft = 0;

  // Last sent values to avoid duplicate payloads
  double _lastSentLeftX = 0.0;
  double _lastSentLeftY = 0.0;
  double _lastSentRightX = 0.0;
  double _lastSentRightY = 0.0;

  // Getters to check engine state
  bool isLeftActive() => _activeLeft != null;
  bool isRightActive() => _activeRight != null;

  void init(void Function(Map<String, dynamic> payload) sendFn) {
    _sendFn = sendFn;
    _ticker?.dispose();
    _lastTickElapsed = Duration.zero;
    _ticker = Ticker(_onTick);
    _ticker!.start();
  }

  void dispose() {
    _ticker?.dispose();
    _ticker = null;
    _sendFn = null;
    
    // Clean up active routes
    if (_activeLeft != null) {
      try {
        GestureBinding.instance.pointerRouter.removeRoute(_activeLeft!.pointerId, _leftPointerRoute);
      } catch (_) {}
      _activeLeft = null;
    }
    if (_activeRight != null) {
      try {
        GestureBinding.instance.pointerRouter.removeRoute(_activeRight!.pointerId, _rightPointerRoute);
      } catch (_) {}
      _activeRight = null;
    }
  }

  void releaseLeftIfMatched(int controlHashCode) {
    if (_activeLeft != null && _activeLeft!.controlHashCode == controlHashCode) {
      debugPrint('[INPUT ENGINE] Widget dispose matched active left pointer. Releasing.');
      _releaseLeftStick();
    }
  }

  void releaseRightIfMatched(int controlHashCode) {
    if (_activeRight != null && _activeRight!.controlHashCode == controlHashCode) {
      debugPrint('[INPUT ENGINE] Widget dispose matched active right pointer. Releasing.');
      _releaseRightStick();
    }
  }

  void _onTick(Duration elapsed) {
    if (_sendFn == null) return;

    final double deltaTime = _lastTickElapsed == Duration.zero
        ? 0.016
        : (elapsed - _lastTickElapsed).inMicroseconds / 1000000.0;
    _lastTickElapsed = elapsed;

    // Process Left Stick State
    if (_activeLeft != null) {
      final sx = (_leftX * _leftSensitivity).clamp(-1.0, 1.0);
      final sy = (_leftY * _leftSensitivity).clamp(-1.0, 1.0);

      _lastSentLeftX = sx;
      _lastSentLeftY = sy;
      _sendFn!({'type': 'stick', 'x': sx, 'y': sy});
    } else {
      if (_lastSentLeftX != 0.0 || _lastSentLeftY != 0.0 || _leftZeroSendsLeft > 0) {
        if (_lastSentLeftX != 0.0 || _lastSentLeftY != 0.0) {
          _lastSentLeftX = 0.0;
          _lastSentLeftY = 0.0;
          _leftZeroSendsLeft = 3;
        }
        _sendFn!({'type': 'stick', 'x': 0.0, 'y': 0.0});
        _leftZeroSendsLeft--;
      }
    }

    // Process Right Stick State
    if (_activeRight != null) {
      if (_rightLayout == 'RS_SWIPE') {
        if (_swipeHasMovedThisTick) {
          final delta = _swipeCurrentPos - _swipeLastTickPos;
          const double fullDeflectionDelta = 25.0;

          double baseDeltaX = delta.dx / fullDeflectionDelta;
          double baseDeltaY = -delta.dy / fullDeflectionDelta;

          double deltaDistance = delta.distance;
          double velocity = deltaTime > 0 ? deltaDistance / deltaTime : 0.0;

          double factor = 1.0;
          final intensity = _rightConfig.swipeAccelerationIntensity;
          if (intensity > 0.0 && velocity > 0.0) {
            factor = 1.0 + intensity * (velocity / 300.0);
            if (factor > 8.0) factor = 8.0;
          }

          _swipeStickX = (baseDeltaX * factor).clamp(-1.0, 1.0);
          _swipeStickY = (baseDeltaY * factor).clamp(-1.0, 1.0);

          _swipeLastTickPos = _swipeCurrentPos;
          _swipeHasMovedThisTick = false;
        } else {
          final decay = _rightConfig.returnToCenterSpeed;
          double adjustedDecay = (decay * (deltaTime / 0.033)).clamp(0.0, 1.0);
          _swipeStickX = _swipeStickX * (1.0 - adjustedDecay);
          _swipeStickY = _swipeStickY * (1.0 - adjustedDecay);
          _swipeLastTickPos = _swipeCurrentPos;
        }

        _rightX = _swipeStickX;
        _rightY = _swipeStickY;

        // Diagnostic log for Swipe Pad
        debugPrint('[INPUT ENGINE] Swipe Pad:\n'
            '  Pointer ID: ${_activeRight!.pointerId}\n'
            '  Global Position: $_rightTouchCurrentGlobal\n'
            '  Local Position: $_swipeCurrentPos\n'
            '  Swipe Raw Output Vector: ($_rightX, $_rightY)');
      }

      final processed = _processRightStickOutput(_rightX, _rightY);

      _lastSentRightX = processed.dx;
      _lastSentRightY = processed.dy;
      _sendFn!({'type': 'rstick', 'x': processed.dx, 'y': processed.dy});
    } else {
      if (_lastSentRightX != 0.0 || _lastSentRightY != 0.0 || _rightZeroSendsLeft > 0) {
        if (_lastSentRightX != 0.0 || _lastSentRightY != 0.0) {
          _lastSentRightX = 0.0;
          _lastSentRightY = 0.0;
          _rightZeroSendsLeft = 3;
        }
        _sendFn!({'type': 'rstick', 'x': 0.0, 'y': 0.0});
        _rightZeroSendsLeft--;
      }
    }
  }

  // --- LEFT STICK API ---

  void handleLeftPointerDown({
    required PointerDownEvent event,
    required Size parentSize,
    required MovementMode mode,
    required double sensitivity,
    required CoordinateConverter converter,
    required ValueNotifier<Offset> visualOffset,
    required ValueNotifier<bool> active,
    required ValueNotifier<Offset> basePos,
    required String controlId,
    required int controlHashCode,
    required double baseSize,
    Offset Function(Offset localPos)? clampBase,
  }) {
    // [INSTRUMENTATION] Pointer reuse and collision check
    if (_activeLeft != null) {
      debugPrint('[INSTRUMENTATION] WARNING: Left pointer registration collision! Active Left Pointer: ${_activeLeft!.pointerId} (${_activeLeft!.controlId}), New Pointer: ${event.pointer} ($controlId)');
      if (_activeLeft!.pointerId == event.pointer) {
        debugPrint('[INSTRUMENTATION] WARNING: EXACT SAME pointer ID ${event.pointer} reused for Left Stick down while already active!');
      }
      debugPrint('[INPUT ENGINE] Stale left pointer ${_activeLeft!.pointerId} detected. Force releasing.');
      _releaseLeftStick();
    }
    if (_activeRight != null && _activeRight!.pointerId == event.pointer) {
      debugPrint('[INSTRUMENTATION] WARNING: Left Pointer ID ${event.pointer} matches active Right Stick pointer! Right Stick: ${_activeRight!.controlId}');
    }

    _activeLeft = ActiveControlState(
      pointerId: event.pointer,
      controlId: controlId,
      controlHashCode: controlHashCode,
      visualOffset: visualOffset,
      active: active,
      basePos: basePos,
      converter: converter,
      clampBase: clampBase,
      baseSize: baseSize,
    );

    _leftMode = mode;
    _leftSensitivity = sensitivity;
    _leftSize = parentSize;

    final localPos = converter(event.position);
    _leftTouchCurrent = localPos;
    _leftTouchCurrentGlobal = event.position;

    if (mode == MovementMode.floatingJoystick) {
      if (clampBase != null) {
        _leftBaseLocal = clampBase(localPos);
      } else {
        final double padding = baseSize / 2;
        final clampedX = localPos.dx.clamp(padding, parentSize.width - padding);
        final clampedY = localPos.dy.clamp(padding, parentSize.height - padding);
        _leftBaseLocal = Offset(clampedX, clampedY);
      }
    } else {
      _leftBaseLocal = Offset(24.0 + baseSize / 2, parentSize.height - 8.0 - baseSize / 2);
    }

    _activeLeft!.active.value = true;
    _activeLeft!.basePos.value = _leftBaseLocal;

    _updateLeftStickMath();

    debugPrint(
      '${mode == MovementMode.floatingJoystick ? "FloatingLeftStick" : "FixedLeftStick"} #$controlHashCode\n'
      'Pointer: ${event.pointer}\n'
      'Registered as: $controlId\n'
      'Activated\n'
      '  Visual Notifier Hash: ${identityHashCode(visualOffset)}\n'
      '  Active Notifier Hash: ${identityHashCode(active)}\n'
      '  BasePos Notifier Hash: ${identityHashCode(basePos)}'
    );

    GestureBinding.instance.pointerRouter.addRoute(event.pointer, _leftPointerRoute);
  }

  void _leftPointerRoute(PointerEvent event) {
    debugPrint('[INSTRUMENTATION] Left Router Event type: ${event.runtimeType}, pointerId: ${event.pointer}, position: ${event.position}');
    if (_activeLeft == null || event.pointer != _activeLeft!.pointerId) return;

    if (event is PointerMoveEvent) {
      _leftTouchCurrentGlobal = event.position;
      _leftTouchCurrent = _activeLeft!.converter(event.position);
      _updateLeftStickMath();
    } else if (event is PointerUpEvent || event is PointerCancelEvent) {
      _releaseLeftStick();
    }
  }

  void _releaseLeftStick() {
    if (_activeLeft != null) {
      debugPrint(
        '${_activeLeft!.controlId.contains("floating") ? "FloatingLeftStick" : "FixedLeftStick"} #${_activeLeft!.controlHashCode}\n'
        'Pointer: ${_activeLeft!.pointerId}\n'
        'Registered as: ${_activeLeft!.controlId}\n'
        'Deactivated'
      );

      try {
        GestureBinding.instance.pointerRouter.removeRoute(_activeLeft!.pointerId, _leftPointerRoute);
      } catch (_) {}
      
      try {
        _activeLeft!.active.value = false;
      } catch (e) {
        debugPrint('[INSTRUMENTATION] ERROR: Failed setting left active value: $e');
      }
      try {
        _activeLeft!.visualOffset.value = Offset.zero;
      } catch (e) {
        debugPrint('[INSTRUMENTATION] ERROR: Failed setting left visualOffset value: $e');
      }
      _activeLeft = null;
    }
    _leftX = 0.0;
    _leftY = 0.0;
  }

  void _updateLeftStickMath() {
    if (_activeLeft == null) return;

    final double baseSize = _activeLeft!.baseSize;
    final double maxDistance = baseSize / 2;
    Offset delta;

    if (_leftMode == MovementMode.floatingJoystick) {
      delta = _leftTouchCurrent - _leftBaseLocal;
      double distance = delta.distance;
      final direction = delta.direction;

      if (distance > maxDistance) {
        Offset proposedBase = _leftTouchCurrent - Offset.fromDirection(direction, maxDistance);

        if (_activeLeft!.clampBase != null) {
          _leftBaseLocal = _activeLeft!.clampBase!(proposedBase);
        } else {
          final padding = baseSize / 2;
          double clampedX = proposedBase.dx.clamp(padding, _leftSize.width - padding);
          double clampedY = proposedBase.dy.clamp(padding, _leftSize.height - padding);
          _leftBaseLocal = Offset(clampedX, clampedY);
        }
        _activeLeft!.basePos.value = _leftBaseLocal;

        delta = _leftTouchCurrent - _leftBaseLocal;
        distance = delta.distance;
      }

      final clampedDistance = distance.clamp(0.0, maxDistance);
      _activeLeft!.visualOffset.value = Offset.fromDirection(delta.direction, clampedDistance);

      final rawDx = delta.dx / maxDistance;
      final rawDy = delta.dy / maxDistance;

      _leftX = rawDx.clamp(-1.0, 1.0);
      _leftY = -rawDy.clamp(-1.0, 1.0);
    } else {
      // Fixed stick Joystick
      final double size = baseSize;
      final center = _leftBaseLocal;
      delta = _leftTouchCurrent - center;
      final dx = delta.dx / (size / 2);
      final dy = delta.dy / (size / 2);

      _leftX = dx.clamp(-1.0, 1.0);
      _leftY = -dy.clamp(-1.0, 1.0);

      double distance = delta.distance;
      double clampedDistance = distance.clamp(0.0, size / 2);
      final direction = delta.direction;

      double visualX = math.cos(direction) * (clampedDistance / (size / 2));
      double visualY = math.sin(direction) * (clampedDistance / (size / 2));

      _activeLeft!.visualOffset.value = Offset(
        visualX * (size / 2 - 20),
        visualY * (size / 2 - 20),
      );
    }

    final double mag = delta.distance;
    final Offset normalized = mag > 0.0 ? delta / mag : Offset.zero;

    // Diagnostic logging
    debugPrint('[INPUT ENGINE] Left Stick:\n'
        '  Pointer ID: ${_activeLeft!.pointerId}\n'
        '  Global Position: $_leftTouchCurrentGlobal\n'
        '  Local Position: $_leftTouchCurrent\n'
        '  Control Center: $_leftBaseLocal\n'
        '  Raw Delta: $delta\n'
        '  Normalized Vector: $normalized\n'
        '  Final Output Vector: ($_leftX, $_leftY)');
  }

  // --- RIGHT STICK API ---

  void handleRightPointerDown({
    required PointerDownEvent event,
    required Size parentSize,
    required String layout,
    required RightStickConfig config,
    required CoordinateConverter converter,
    required ValueNotifier<Offset> visualOffset,
    required ValueNotifier<bool> active,
    required ValueNotifier<Offset> basePos,
    required String controlId,
    required int controlHashCode,
    required double baseSize,
    Offset Function(Offset localPos)? clampBase,
  }) {
    // [INSTRUMENTATION] Pointer reuse and collision check
    if (_activeRight != null) {
      debugPrint('[INSTRUMENTATION] WARNING: Right pointer registration collision! Active Right Pointer: ${_activeRight!.pointerId} (${_activeRight!.controlId}), New Pointer: ${event.pointer} ($controlId)');
      if (_activeRight!.pointerId == event.pointer) {
        debugPrint('[INSTRUMENTATION] WARNING: EXACT SAME pointer ID ${event.pointer} reused for Right Stick down while already active!');
      }
      debugPrint('[INPUT ENGINE] Stale right pointer ${_activeRight!.pointerId} detected. Force releasing.');
      _releaseRightStick();
    }
    if (_activeLeft != null && _activeLeft!.pointerId == event.pointer) {
      debugPrint('[INSTRUMENTATION] WARNING: Right Pointer ID ${event.pointer} matches active Left Stick pointer! Left Stick: ${_activeLeft!.controlId}');
    }

    _activeRight = ActiveControlState(
      pointerId: event.pointer,
      controlId: controlId,
      controlHashCode: controlHashCode,
      visualOffset: visualOffset,
      active: active,
      basePos: basePos,
      converter: converter,
      clampBase: clampBase,
      baseSize: baseSize,
    );

    _rightLayout = layout;
    _rightConfig = config;
    _rightSize = parentSize;

    final localPos = converter(event.position);
    _rightTouchCurrent = localPos;
    _rightTouchCurrentGlobal = event.position;

    if (layout == 'RS_BUTTON') {
      if (clampBase != null) {
        _rightBaseLocal = clampBase(localPos);
      } else {
        final double padding = baseSize / 2;
        final clampedX = localPos.dx.clamp(padding, parentSize.width - padding);
        final clampedY = localPos.dy.clamp(padding, parentSize.height - padding);
        _rightBaseLocal = Offset(clampedX, clampedY);
      }
    } else if (layout == 'RS_FIXED') {
      _rightBaseLocal = Offset(parentSize.width / 2, parentSize.height / 2);
    } else if (layout == 'RS_SWIPE') {
      _rightBaseLocal = localPos;
      _swipeLastTickPos = localPos;
      _swipeCurrentPos = localPos;
      _swipeHasMovedThisTick = false;
      _swipeStickX = 0.0;
      _swipeStickY = 0.0;
    }

    _activeRight!.active.value = true;
    _activeRight!.basePos.value = _rightBaseLocal;

    _updateRightStickMath(isInitial: true);

    debugPrint(
      '${layout == "RS_BUTTON" ? "FloatingRightStick" : layout == "RS_FIXED" ? "FixedRightStick" : "SwipePad"} #$controlHashCode\n'
      'Pointer: ${event.pointer}\n'
      'Registered as: $controlId\n'
      'Activated\n'
      '  Visual Notifier Hash: ${identityHashCode(visualOffset)}\n'
      '  Active Notifier Hash: ${identityHashCode(active)}\n'
      '  BasePos Notifier Hash: ${identityHashCode(basePos)}'
    );

    GestureBinding.instance.pointerRouter.addRoute(event.pointer, _rightPointerRoute);
  }

  void _rightPointerRoute(PointerEvent event) {
    debugPrint('[INSTRUMENTATION] Right Router Event type: ${event.runtimeType}, pointerId: ${event.pointer}, position: ${event.position}');
    if (_activeRight == null || event.pointer != _activeRight!.pointerId) return;

    if (event is PointerMoveEvent) {
      _rightTouchCurrentGlobal = event.position;
      final localPos = _activeRight!.converter(event.position);
      _rightTouchCurrent = localPos;
      if (_rightLayout == 'RS_SWIPE') {
        _swipeCurrentPos = localPos;
        _swipeHasMovedThisTick = true;
      } else {
        _updateRightStickMath();
      }
    } else if (event is PointerUpEvent || event is PointerCancelEvent) {
      _releaseRightStick();
    }
  }

  void _releaseRightStick() {
    if (_activeRight != null) {
      final String controlType = _activeRight!.controlId.split("_")[0];
      debugPrint(
        '${controlType == "RS-BUTTON" ? "FloatingRightStick" : controlType == "RS-FIXED" ? "FixedRightStick" : "SwipePad"} #${_activeRight!.controlHashCode}\n'
        'Pointer: ${_activeRight!.pointerId}\n'
        'Registered as: ${_activeRight!.controlId}\n'
        'Deactivated'
      );

      try {
        GestureBinding.instance.pointerRouter.removeRoute(_activeRight!.pointerId, _rightPointerRoute);
      } catch (_) {}
      
      try {
        _activeRight!.active.value = false;
      } catch (e) {
        debugPrint('[INSTRUMENTATION] ERROR: Failed setting right active value: $e');
      }
      try {
        _activeRight!.visualOffset.value = Offset.zero;
      } catch (e) {
        debugPrint('[INSTRUMENTATION] ERROR: Failed setting right visualOffset value: $e');
      }
      _activeRight = null;
    }
    _rightX = 0.0;
    _rightY = 0.0;
  }

  void _updateRightStickMath({bool isInitial = false}) {
    if (_activeRight == null) return;

    final double baseSize = _activeRight!.baseSize;
    final double maxDistance = baseSize / 2;
    Offset delta;

    if (_rightLayout == 'RS_BUTTON') {
      delta = _rightTouchCurrent - _rightBaseLocal;
      double distance = delta.distance;
      final direction = delta.direction;

      if (distance > maxDistance) {
        final proposedBase = _rightTouchCurrent - Offset.fromDirection(direction, maxDistance);
        if (_activeRight!.clampBase != null) {
          _rightBaseLocal = _activeRight!.clampBase!(proposedBase);
        } else {
          final double padding = baseSize / 2;
          final clampedX = proposedBase.dx.clamp(padding, _rightSize.width - padding);
          final clampedY = proposedBase.dy.clamp(padding, _rightSize.height - padding);
          _rightBaseLocal = Offset(clampedX, clampedY);
        }
        _activeRight!.basePos.value = _rightBaseLocal;

        delta = _rightTouchCurrent - _rightBaseLocal;
        distance = delta.distance;
      }

      final clampedDistance = distance.clamp(0.0, maxDistance);
      _activeRight!.visualOffset.value = Offset.fromDirection(delta.direction, clampedDistance);

      final rawDx = delta.dx / maxDistance;
      final rawDy = delta.dy / maxDistance;
      _rightX = rawDx.clamp(-1.0, 1.0);
      _rightY = -rawDy.clamp(-1.0, 1.0);
    } else if (_rightLayout == 'RS_FIXED') {
      final size = baseSize;
      final center = _rightBaseLocal;
      delta = _rightTouchCurrent - center;
      final dx = delta.dx / (size / 2);
      final dy = delta.dy / (size / 2);

      _rightX = dx.clamp(-1.0, 1.0);
      _rightY = -dy.clamp(-1.0, 1.0);

      double distance = delta.distance;
      double clampedDistance = distance.clamp(0.0, size / 2);
      final direction = delta.direction;

      double visualX = math.cos(direction) * (clampedDistance / (size / 2));
      double visualY = math.sin(direction) * (clampedDistance / (size / 2));

      _activeRight!.visualOffset.value = Offset(
        visualX * (size / 2 - 20),
        visualY * (size / 2 - 20),
      );
    } else {
      // Swipe Pad
      return;
    }

    final double mag = delta.distance;
    final Offset normalized = mag > 0.0 ? delta / mag : Offset.zero;
    final processed = _processRightStickOutput(_rightX, _rightY);

    // Diagnostic logging
    debugPrint('[INPUT ENGINE] Right Stick ($_rightLayout):\n'
        '  Pointer ID: ${_activeRight!.pointerId}\n'
        '  Global Position: $_rightTouchCurrentGlobal\n'
        '  Local Position: $_rightTouchCurrent\n'
        '  Control Center: $_rightBaseLocal\n'
        '  Raw Delta: $delta\n'
        '  Normalized Vector: $normalized\n'
        '  Final Output Vector: (${processed.dx}, ${processed.dy})');
  }

  Offset _processRightStickOutput(double rawX, double rawY) {
    double x = rawX;
    double y = rawY;
    double magnitude = math.sqrt(x * x + y * y);
    if (magnitude < _rightConfig.deadzone) {
      x = 0;
      y = 0;
    } else {
      double scaledMagnitude = (magnitude - _rightConfig.deadzone) / (1.0 - _rightConfig.deadzone);
      x = (x / magnitude) * scaledMagnitude;
      y = (y / magnitude) * scaledMagnitude;
    }

    x *= _rightConfig.sensitivity;
    y *= _rightConfig.sensitivity;

    // Apply anti-deadzone and response curve transformation
    final double scaledMag = math.sqrt(x * x + y * y);
    if (scaledMag > 0.0) {
      final double mIn = scaledMag.clamp(0.0, 1.0);
      double mOut;
      if (mIn == 0.0) {
        mOut = 0.0;
      } else {
        double f;
        final double strength = _rightConfig.responseCurve;
        if (strength < 0.01) {
          f = mIn;
        } else {
          final double k = math.exp(strength * 3.0) - 1.0;
          f = math.log(1.0 + k * mIn) / math.log(1.0 + k);
        }
        final double a = _rightConfig.antiDeadzone;
        mOut = a + (1.0 - a) * f;
      }
      x = (x / scaledMag) * mOut;
      y = (y / scaledMag) * mOut;
    }

    x = x.clamp(-1.0, 1.0);
    y = y.clamp(-1.0, 1.0);

    if (_rightConfig.invertX) x = -x;
    if (_rightConfig.invertY) y = -y;

    return Offset(x, y);
  }

  // --- GENERAL BUTTON API ---

  void updateButtonState(String xinputId, String state, bool tapHapticsEnabled) {
    if (state == 'down' && tapHapticsEnabled) {
      try {
        HapticsManager.instance.softTap();
      } catch (_) {}
    }
    _sendFn?.call({'type': 'button', 'id': xinputId, 'state': state});
  }
}
