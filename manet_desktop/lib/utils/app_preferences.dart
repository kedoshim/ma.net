import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:window_manager/window_manager.dart';
import '../services/access_service.dart' show AccessMode;

/// Host-side preferences that persist between sessions.
class AppPreferences {
  static const _controllerModeKey = 'controller_mode';
  static const _fullScreenKey = 'full_screen';
  static const _matchSecondsKey = 'tournament_match_seconds';
  static const _freeModeKey = 'free_mode_enabled';
  static const _abandonCloseKey = 'abandon_close_minutes';
  static const _consoleModeKey = 'console_mode';
  static const _lobbyStartRuleKey = 'lobby_start_rule';
  static const _mousePasswordKey = 'mouse_password';
  static const _accessModeLanKey = 'access_mode_lan';
  static const _accessModeOnlineKey = 'access_mode_online';
  static const _roomPasswordKey = 'room_password';
  static const _onlineRuleOverrideKey = 'access_online_override';
  static const _roomPasswordOnlineKey = 'room_password_online';
  static const _networkModeKey = 'network_mode';
  static const _qrTargetKey = 'qr_target';
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

  /// Minutes a game nobody is connected to waits before closing (0: never).
  static Future<int> abandonCloseMinutes() async {
    final prefs = await SharedPreferences.getInstance();
    return (prefs.getInt(_abandonCloseKey) ?? 30).clamp(0, 120);
  }

  static Future<void> setAbandonCloseMinutes(int minutes) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_abandonCloseKey, minutes.clamp(0, 120));
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

  /// Console mode: no slot settings, virtual pads are created when a game
  /// starts. Off = tool mode, the technical lobby with every setting.
  static Future<bool> consoleMode() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_consoleModeKey) ?? true;
  }

  static Future<void> setConsoleMode(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_consoleModeKey, value);
  }

  /// Console lobby: the game selection starts when the "majority" (default)
  /// or "all" of the players walked out through the right edge.
  static Future<String> lobbyStartRule() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_lobbyStartRuleKey) == 'all' ? 'all' : 'majority';
  }

  /// Console mode: password a phone needs for mouse mode (empty: mouse
  /// mode only in free mode).
  static Future<String> mousePassword() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_mousePasswordKey) ?? '';
  }

  static Future<void> setMousePassword(String value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_mousePasswordKey, value.trim());
  }

  /// Who may join from the local network (default: anyone).
  static Future<AccessMode> accessModeLan() async {
    final prefs = await SharedPreferences.getInstance();
    return _accessMode(prefs.getString(_accessModeLanKey), AccessMode.open);
  }

  static Future<void> setAccessModeLan(AccessMode mode) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_accessModeLanKey, mode.name);
  }

  /// Who may join through "Play online" (default: the host approves).
  static Future<AccessMode> accessModeOnline() async {
    final prefs = await SharedPreferences.getInstance();
    return _accessMode(prefs.getString(_accessModeOnlineKey), AccessMode.approval);
  }

  static Future<void> setAccessModeOnline(AccessMode mode) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_accessModeOnlineKey, mode.name);
  }

  static AccessMode _accessMode(String? value, AccessMode fallback) =>
      AccessMode.values.firstWhere((mode) => mode.name == value, orElse: () => fallback);

  static Future<String> roomPassword() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_roomPasswordKey) ?? '';
  }

  static Future<void> setRoomPassword(String value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_roomPasswordKey, value.trim());
  }

  /// Whether internet joins follow their own rule instead of the global
  /// one. Unset: on when the saved rules already differ (or none saved,
  /// since online defaults to approval).
  static Future<bool> onlineRuleOverride() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getBool(_onlineRuleOverrideKey);
    if (saved != null) return saved;
    return await accessModeLan() != await accessModeOnline();
  }

  static Future<void> setOnlineRuleOverride(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_onlineRuleOverrideKey, value);
  }

  /// Password for internet joins when they have their own rule (unset:
  /// the global one).
  static Future<String> roomPasswordOnline() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_roomPasswordOnlineKey) ?? await roomPassword();
  }

  static Future<void> setRoomPasswordOnline(String value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_roomPasswordOnlineKey, value.trim());
  }

  /// 'local', 'both' or 'online' (see NetworkModeService).
  static Future<String> networkMode() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_networkModeKey) ?? 'local';
  }

  static Future<void> setNetworkMode(String value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_networkModeKey, value);
  }

  /// Which QR the lobby and the overlay show in "both": 'local' or 'online'.
  static Future<String> qrTarget() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_qrTargetKey) ?? 'online';
  }

  static Future<void> setQrTarget(String value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_qrTargetKey, value);
  }

  static Future<void> setLobbyStartRule(String value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_lobbyStartRuleKey, value == 'all' ? 'all' : 'majority');
  }

  /// Re-applies the full screen preference (e.g. after coming back from a
  /// game, since minimizing drops full screen).
  static Future<void> applyFullScreen() async {
    if (await fullScreen()) await windowManager.setFullScreen(true);
  }
}
