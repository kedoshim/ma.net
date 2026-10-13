import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:window_manager/window_manager.dart';

/// Host-side preferences that persist between sessions.
class AppPreferences {
  static const _controllerModeKey = 'controller_mode';
  static const _fullScreenKey = 'full_screen';
  static const _matchSecondsKey = 'tournament_match_seconds';
  static const _freeModeKey = 'free_mode_enabled';
  static const _launcherCardStyleKey = 'launcher_card_style';
  static const _launcherGridRowsKey = 'launcher_grid_rows';
  static const _launcherSortOrderKey = 'launcher_sort_order';

  static final ValueNotifier<String> cardStyleNotifier = ValueNotifier<String>('cover_only');
  static final ValueNotifier<int> gridRowsNotifier = ValueNotifier<int>(2);
  static final ValueNotifier<String> sortOrderNotifier = ValueNotifier<String>('recent');

  static Future<void> initLauncherPreferences() async {
    final prefs = await SharedPreferences.getInstance();
    cardStyleNotifier.value = prefs.getString(_launcherCardStyleKey) ?? 'cover_only';
    gridRowsNotifier.value = (prefs.getInt(_launcherGridRowsKey) ?? 2).clamp(1, 3);
    sortOrderNotifier.value = prefs.getString(_launcherSortOrderKey) ?? 'recent';
  }

  static Future<void> setCardStyle(String style) async {
    cardStyleNotifier.value = style;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_launcherCardStyleKey, style);
  }

  static Future<void> setGridRows(int rows) async {
    final clamped = rows.clamp(1, 3);
    gridRowsNotifier.value = clamped;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_launcherGridRowsKey, clamped);
  }

  static Future<void> setSortOrder(String order) async {
    sortOrderNotifier.value = order;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_launcherSortOrderKey, order);
  }

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

  /// How long each tournament duel lasts.
  static Future<int> matchSeconds() async {
    final prefs = await SharedPreferences.getInstance();
    return (prefs.getInt(_matchSecondsKey) ?? 10).clamp(3, 60);
  }

  static Future<void> setMatchSeconds(int seconds) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_matchSecondsKey, seconds.clamp(3, 60));
  }

  /// Whether the game selection offers free mode (MaNet steps aside and
  /// phones are plain gamepads for any game).
  static Future<bool> freeModeEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_freeModeKey) ?? true;
  }

  static Future<void> setFreeModeEnabled(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_freeModeKey, value);
  }

  /// Re-applies the full screen preference (e.g. after coming back from a
  /// game, since minimizing drops full screen).
  static Future<void> applyFullScreen() async {
    if (await fullScreen()) await windowManager.setFullScreen(true);
  }
}
