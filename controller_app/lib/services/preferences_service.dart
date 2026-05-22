import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';
import '../models/player_face.dart';

class PreferencesService {
  PreferencesService._();
  static final PreferencesService instance = PreferencesService._();

  SharedPreferences? _prefs;

  Future<SharedPreferences> get _getInstance async {
    _prefs ??= await SharedPreferences.getInstance();
    return _prefs!;
  }

  // --- Connection Settings ---
  Future<void> saveConnection(String host, int port, bool isHttps) async {
    final p = await _getInstance;
    await p.setString('server_host', host);
    await p.setInt('server_port', port);
    await p.setBool('server_https', isHttps);
  }

  Future<void> clearConnection() async {
    final p = await _getInstance;
    await p.remove('server_host');
    await p.remove('server_port');
    await p.remove('server_https');
  }

  Future<String?> getServerHost() async =>
      (await _getInstance).getString('server_host');
  Future<int?> getServerPort() async =>
      (await _getInstance).getInt('server_port');
  Future<bool?> getServerHttps() async =>
      (await _getInstance).getBool('server_https');

  // --- Player Identity ---
  Future<String> getDeviceId() async {
    final p = await _getInstance;
    String? id = p.getString('device_id');
    if (id == null) {
      id = const Uuid().v4();
      await p.setString('device_id', id);
    }
    return id;
  }

  // --- Slot Memory ---
  Future<void> setLastKnownSlot(int slot) async =>
      (await _getInstance).setInt('last_known_slot', slot);
  Future<int?> getLastKnownSlot() async =>
      (await _getInstance).getInt('last_known_slot');

  Future<PlayerFaceData> getOrCreatePlayerFace() async {
    final p = await _getInstance;
    final stored = p.getString('player_face');
    if (stored != null) {
      try {
        return PlayerFaceData.fromJson(
          jsonDecode(stored) as Map<String, dynamic>,
        );
      } catch (_) {}
    }

    final generated = PlayerFaceData.random();
    await savePlayerFace(generated);
    return generated;
  }

  Future<void> savePlayerFace(PlayerFaceData face) async {
    final p = await _getInstance;
    await p.setString('player_face', jsonEncode(face.toJson()));
  }

  // --- Appearance ---
  Future<void> setSelectedTheme(int themeIndex) async =>
      (await _getInstance).setInt('selectedTheme', themeIndex);
  Future<int> getSelectedTheme() async =>
      (await _getInstance).getInt('selectedTheme') ?? 0;

  // --- Controls & Layout ---
  Future<void> setDpadMode(bool mode) async =>
      (await _getInstance).setBool('dpadMode', mode);
  Future<bool> getDpadMode() async =>
      (await _getInstance).getBool('dpadMode') ?? false;

  Future<void> setMouseModeEnabled(bool enabled) async =>
      (await _getInstance).setBool('mouseModeEnabled', enabled);
  Future<bool> getMouseModeEnabled() async =>
      (await _getInstance).getBool('mouseModeEnabled') ?? false;

  Future<void> setButtonOrder(List<String> order) async =>
      (await _getInstance).setStringList('buttonOrder', order);
  Future<List<String>?> getButtonOrder() async =>
      (await _getInstance).getStringList('buttonOrder');

  Future<void> setButtonVisibility(Map<String, bool> visibility) async {
    final p = await _getInstance;
    await p.setString('buttonVisibility', jsonEncode(visibility));
  }

  Future<Map<String, bool>?> getButtonVisibility() async {
    final p = await _getInstance;
    final str = p.getString('buttonVisibility');
    if (str == null) return null;
    try {
      final Map<String, dynamic> decoded = jsonDecode(str);
      return decoded.map((k, v) => MapEntry(k, v as bool));
    } catch (_) {
      return null;
    }
  }

  // --- Rumble / Haptics ---
  Future<void> setRumbleEnabled(bool enabled) async =>
      (await _getInstance).setBool('rumbleEnabled', enabled);

  Future<bool> getRumbleEnabled() async =>
      (await _getInstance).getBool('rumbleEnabled') ?? true;

  Future<void> setTapHapticsEnabled(bool enabled) async =>
      (await _getInstance).setBool('tapHapticsEnabled', enabled);

  Future<bool> getTapHapticsEnabled() async =>
      (await _getInstance).getBool('tapHapticsEnabled') ?? true;

  Future<void> setHasSeenEditTutorial(bool seen) async =>
      (await _getInstance).setBool('hasSeenEditTutorial', seen);

  Future<bool> getHasSeenEditTutorial() async =>
      (await _getInstance).getBool('hasSeenEditTutorial') ?? false;
}
