import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:window_manager/window_manager.dart';

import 'host_api_service.dart';

class HostWindowService {
  HostWindowService({required HostApiService api}) : _api = api;

  final HostApiService _api;
  StreamSubscription<Map<String, dynamic>>? _subscription;
  bool _restoreToFullScreen = false;


  void start() {
    _subscription ??= _api.connectAdminSocket().listen(_handleEvent);
  }

  Future<void> dispose() async {
    await _subscription?.cancel();
    _subscription = null;
  }

  Future<void> _handleEvent(Map<String, dynamic> event) async {
    if (event['type'] != 'window_action') return;
    if (event['action'] != 'toggle_visibility') return;

    await toggleVisibility();
  }

  Future<void> toggleVisibility() async {
    try {
      final isVisible = await windowManager.isVisible();
      final isMinimized = await windowManager.isMinimized();

      if (!isVisible || isMinimized) {
        await windowManager.show();
        await windowManager.restore();
        if (_restoreToFullScreen) {
          await windowManager.setFullScreen(true);
          debugPrint('Restored to full screen');
        }
        await windowManager.focus();
        return;
      }

      _restoreToFullScreen = await windowManager.isFullScreen();
      await windowManager.minimize();
    } catch (error, stackTrace) {
      debugPrint('HostWindowService.toggleVisibility failed: $error');
      debugPrintStack(stackTrace: stackTrace);
    }
  }
}
