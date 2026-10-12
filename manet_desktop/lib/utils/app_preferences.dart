import 'package:shared_preferences/shared_preferences.dart';
import 'package:window_manager/window_manager.dart';

/// Host-side preferences that persist between sessions.
class AppPreferences {
  static const _controllerModeKey = 'controller_mode';
  static const _fullScreenKey = 'full_screen';

  /// 'x360' (x•input) or 'ds4' (d•input). Defaults to x•input.
  static Future<String> controllerMode() async {
    final prefs = await SharedPreferences.getInstance();
    final mode = prefs.getString(_controllerModeKey);
    return mode == 'ds4' ? 'ds4' : 'x360';
  }

  static Future<void> setControllerMode(String mode) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_controllerModeKey, mode == 'ds4' ? 'ds4' : 'x360');
  }

  /// MaNet covers the whole screen by default (couch/TV use).
  static Future<bool> fullScreen() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_fullScreenKey) ?? true;
  }

  static Future<void> setFullScreen(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_fullScreenKey, value);
    await windowManager.setFullScreen(value);
  }

  /// Re-applies the full screen preference (e.g. after coming back from a
  /// game, since minimizing drops full screen).
  static Future<void> applyFullScreen() async {
    if (await fullScreen()) await windowManager.setFullScreen(true);
  }
}
