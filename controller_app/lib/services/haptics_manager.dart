import 'dart:async';
import 'package:flutter/foundation.dart'
    show kIsWeb, defaultTargetPlatform, TargetPlatform;
import 'package:flutter/material.dart';
import 'package:vibration/vibration.dart';
import 'preferences_service.dart';

class HapticsManager {
  HapticsManager._();
  static final HapticsManager instance = HapticsManager._();

  bool _enabled = true;
  double _lastVibeAt = 0.0;
  double _lastIntensity = -1.0;
  Timer? _rumbleStopTimer;
  bool _hasAmplitudeControl = false;

  Future<void> init() async {
    _enabled = await PreferencesService.instance.getRumbleEnabled();
    if (_isMobileOS) {
      _hasAmplitudeControl = await Vibration.hasAmplitudeControl();
    }
  }

  Future<void> setEnabled(bool enabled) async {
    _enabled = enabled;
    await PreferencesService.instance.setRumbleEnabled(enabled);
  }

  bool get enabled => _enabled;

  bool get _isMobileOS {
    if (kIsWeb) return false;
    return defaultTargetPlatform == TargetPlatform.android ||
        defaultTargetPlatform == TargetPlatform.iOS;
  }

  void onRumble(double weak, double strong) {
    if (!_enabled) return;
    if (!_isMobileOS) return;

    final intensity = (weak > strong) ? weak : strong;
    if (intensity <= 0.02) {
      _lastIntensity = 0.0;
      _lastVibeAt = 0.0;
      _rumbleStopTimer?.cancel();
      Vibration.cancel();
      return;
    }

    final now = DateTime.now().millisecondsSinceEpoch / 1000.0;
    final isSameIntensity = (_lastIntensity - intensity).abs() < 0.1;

    // If we receive similar continuous requests, don't restart the motor (which causes stutters).
    // The OS hardware will loop it perfectly. We just reset the safety timer.
    if (isSameIntensity && (now - _lastVibeAt < 8.0)) {
      _resetSafetyTimer();
      return;
    }

    _lastVibeAt = now;
    _lastIntensity = intensity;
    // Map intensity to haptic patterns
    try {
      debugPrint(
        'HapticsManager: onRumble weak=$weak strong=$strong intensity=$intensity',
      );
    } catch (_) {}

    _startRumbleLoop(intensity);
    _resetSafetyTimer();
  }

  void _startRumbleLoop(double intensity) {
    if (defaultTargetPlatform == TargetPlatform.android) {
      // Android natively supports repeating waveforms at the hardware level.
      // This bypasses Android OS truncation limits and eliminates Dart timer stutter.
      if (_hasAmplitudeControl) {
        final amplitude = (intensity * 255).clamp(1, 255).toInt();
        Vibration.vibrate(
          pattern: [0, 500],
          intensities: [0, amplitude],
          repeat: 0,
        );
      } else {
        Vibration.vibrate(pattern: [0, 500], repeat: 0);
      }
    } else {
      // iOS doesn't truncate long requests, so we can just ask for 10 straight seconds.
      final durationMs = 10000;
      if (_hasAmplitudeControl) {
        final amplitude = (intensity * 255).clamp(1, 255).toInt();
        Vibration.vibrate(duration: durationMs, amplitude: amplitude);
      } else {
        Vibration.vibrate(duration: durationMs);
      }
    }
  }

  void _resetSafetyTimer() {
    _rumbleStopTimer?.cancel();
    // Provide a generous safety cutoff (10 seconds) in case the server disconnects/crashes
    _rumbleStopTimer = Timer(const Duration(seconds: 10), () {
      _lastIntensity = 0.0;
      _lastVibeAt = 0.0;
      Vibration.cancel();
    });
  }

  void connectionPulse() {
    if (!_enabled) return;
    if (!_isMobileOS) return;
    try {
      debugPrint('HapticsManager: connectionPulse');
    } catch (_) {}
    Vibration.vibrate(duration: 100);
  }

  void softTap() {
    if (!_enabled) return;
    if (!_isMobileOS) return;

    if (_hasAmplitudeControl) {
      Vibration.vibrate(duration: 24, amplitude: 80);
    } else {
      Vibration.vibrate(duration: 24);
    }
  }
}
