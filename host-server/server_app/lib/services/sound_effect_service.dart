import 'dart:math' as math;

import 'package:media_kit/media_kit.dart';

enum ServerAppSound {
  hover,
  playerJoinPop,
  startButton,
  optionsButton,
  themeSelect,
  dropPlayer,
}

class ServerAppSoundConfig {
  final List<String> assetPaths;
  final double volume;
  final Duration? minimumInterval;
  final String playerKey;
  final bool randomizeAsset;

  const ServerAppSoundConfig({
    required this.assetPaths,
    required this.volume,
    required this.playerKey,
    this.minimumInterval,
    this.randomizeAsset = false,
  });
}

class SoundEffectService {
  SoundEffectService._() {
    for (int i = 0; i < _maxPoolSize; i++) {
      _playerPool.add(Player());
    }
  }

  static final SoundEffectService instance = SoundEffectService._();

  final math.Random _random = math.Random();
  final Map<ServerAppSound, DateTime> _lastPlayedAt = {};

  static const Map<ServerAppSound, ServerAppSoundConfig> _soundConfigs = {
    ServerAppSound.hover: ServerAppSoundConfig(
      assetPaths: ['audio/slot-click.mp3'],
      volume: 1,
      minimumInterval: Duration(milliseconds: 100),
      playerKey: 'hover',
    ),
    ServerAppSound.playerJoinPop: ServerAppSoundConfig(
      assetPaths: [
        'audio/bubble_pop/bubble_pop1.mp3',
        'audio/bubble_pop/bubble_pop2.mp3',
        'audio/bubble_pop/bubble_pop3.mp3',
        'audio/bubble_pop/bubble_pop4.mp3',
      ],
      volume: 1,
      playerKey: 'playerJoinPop',
      randomizeAsset: true,
    ),
    ServerAppSound.startButton: ServerAppSoundConfig(
      assetPaths: ['audio/slot-click.mp3'],
      volume: 1,
      playerKey: 'uiClick',
    ),
    ServerAppSound.optionsButton: ServerAppSoundConfig(
      assetPaths: ['audio/slot-click.mp3'],
      volume: 1,
      playerKey: 'uiClick',
    ),
    ServerAppSound.themeSelect: ServerAppSoundConfig(
      assetPaths: ['audio/slot-click.mp3'],
      volume: 1,
      minimumInterval: Duration(milliseconds: 0),
      playerKey: 'uiClick',
    ),
    ServerAppSound.dropPlayer: ServerAppSoundConfig(
      assetPaths: ['audio/drop1.wav'],
      volume: 0.5,
      playerKey: 'dropPlayer',
    ),
  };

  final List<Player> _playerPool = [];
  int _currentPlayerIndex = 0;
  static const int _maxPoolSize = 5; // Allows 5 overlapping sound effects

  void init() {
    // Calling this forces the singleton to instantiate and pre-allocate the players.
  }

  Player _getNextPlayer() {
    final p = _playerPool[_currentPlayerIndex];
    _currentPlayerIndex = (_currentPlayerIndex + 1) % _maxPoolSize;
    return p;
  }

  Future<void> play(ServerAppSound sound, {double? volume}) async {
    final config = _soundConfigs[sound];
    if (config == null) return;

    final now = DateTime.now();
    final lastPlayedAt = _lastPlayedAt[sound];
    final minimumInterval = config.minimumInterval;

    if (minimumInterval != null &&
        lastPlayedAt != null &&
        now.difference(lastPlayedAt) < minimumInterval) {
      return;
    }

    _lastPlayedAt[sound] = now;

    final assetPath = _resolveAssetPath(config);

    try {
      final player = _getNextPlayer();
      final vol = volume ?? config.volume;

      // Convert to media_kit percentage scale (e.g. 1.0 -> 100%)
      // We clamp at 1000.0 to safely allow up to 10x volume amplification
      final targetVolume = (vol * 100.0).clamp(0.0, 1000.0);
      await player.setVolume(targetVolume);

      await player.open(Media('asset:///assets/$assetPath'));
    } catch (_) {
      // Silently ignore asset/file playback issues.
    }
  }

  Future<void> playHover() => play(ServerAppSound.hover);

  Future<void> playPlayerJoinPop() => play(ServerAppSound.playerJoinPop);

  Future<void> playStartButton() => play(ServerAppSound.startButton);

  Future<void> playOptionsButton() => play(ServerAppSound.optionsButton);

  Future<void> playThemeSelect() => play(ServerAppSound.themeSelect);

  Future<void> playDropPlayer() => play(ServerAppSound.dropPlayer);

  String _resolveAssetPath(ServerAppSoundConfig config) {
    if (config.assetPaths.isEmpty) {
      throw StateError('Sound config must include at least one asset path.');
    }

    if (!config.randomizeAsset || config.assetPaths.length == 1) {
      return config.assetPaths.first;
    }

    return config.assetPaths[_random.nextInt(config.assetPaths.length)];
  }
}
