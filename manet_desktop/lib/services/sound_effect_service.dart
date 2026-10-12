import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter_soloud/flutter_soloud.dart';

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

/// UI sound effects on SoLoud: every clip is decoded into memory once at
/// startup, so playing is instant and overlapping sounds never cut each other
/// off (the old media_kit pool re-opened the file on every play, which made
/// sounds late, dropped or doubled).
class SoundEffectService {
  SoundEffectService._();

  static final SoundEffectService instance = SoundEffectService._();

  // A widget that scales on hover can slide out from under the cursor and
  // back in, firing enter repeatedly; ignore re-entries of the same source.
  static const Duration _hoverReentryWindow = Duration(milliseconds: 400);

  final math.Random _random = math.Random();
  // Throttling is per player key so sounds sharing a clip don't stack.
  final Map<String, DateTime> _lastPlayedAt = {};
  final Map<String, AudioSource> _sources = {};
  Object? _lastHoverSource;
  DateTime? _lastHoverAt;
  Future<void>? _initFuture;
  bool _ready = false;

  static const Map<ServerAppSound, ServerAppSoundConfig> _soundConfigs = {
    ServerAppSound.hover: ServerAppSoundConfig(
      assetPaths: ['audio/slot-click.mp3'],
      volume: 1,
      minimumInterval: Duration(milliseconds: 70),
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
      minimumInterval: Duration(milliseconds: 120),
      playerKey: 'playerJoinPop',
      randomizeAsset: true,
    ),
    ServerAppSound.startButton: ServerAppSoundConfig(
      assetPaths: ['audio/slot-click.mp3'],
      volume: 1,
      minimumInterval: Duration(milliseconds: 40),
      playerKey: 'uiClick',
    ),
    ServerAppSound.optionsButton: ServerAppSoundConfig(
      assetPaths: ['audio/slot-click.mp3'],
      volume: 1,
      minimumInterval: Duration(milliseconds: 40),
      playerKey: 'uiClick',
    ),
    ServerAppSound.themeSelect: ServerAppSoundConfig(
      assetPaths: ['audio/slot-click.mp3'],
      volume: 1,
      minimumInterval: Duration(milliseconds: 40),
      playerKey: 'uiClick',
    ),
    ServerAppSound.dropPlayer: ServerAppSoundConfig(
      assetPaths: ['audio/drop1.wav'],
      volume: 0.5,
      minimumInterval: Duration(milliseconds: 80),
      playerKey: 'dropPlayer',
    ),
  };

  /// Starts the audio engine and preloads every clip. Safe to call repeatedly.
  Future<void> init() => _initFuture ??= _load();

  Future<void> _load() async {
    try {
      final soloud = SoLoud.instance;
      if (!soloud.isInitialized) {
        await soloud.init(bufferSize: 1024);
      }
      final paths = {
        for (final config in _soundConfigs.values) ...config.assetPaths,
      };
      for (final path in paths) {
        _sources[path] = await soloud.loadAsset(
          'assets/$path',
          mode: LoadMode.memory,
        );
      }
      _ready = true;
    } catch (e) {
      debugPrint('[SOUND] Audio engine unavailable, UI sounds disabled: $e');
    }
  }

  /// [source] identifies the widget that triggered a hover, so bouncing in
  /// and out of the same widget doesn't replay the sound.
  Future<void> play(
    ServerAppSound sound, {
    double? volume,
    Object? source,
  }) async {
    if (!_ready) {
      unawaited(init());
      return;
    }
    final config = _soundConfigs[sound];
    if (config == null) return;

    final now = DateTime.now();

    if (sound == ServerAppSound.hover && source != null) {
      final lastAt = _lastHoverAt;
      if (identical(source, _lastHoverSource) &&
          lastAt != null &&
          now.difference(lastAt) < _hoverReentryWindow) {
        return;
      }
      _lastHoverSource = source;
      _lastHoverAt = now;
    }

    final minimumInterval = config.minimumInterval;
    final lastPlayedAt = _lastPlayedAt[config.playerKey];
    if (minimumInterval != null &&
        lastPlayedAt != null &&
        now.difference(lastPlayedAt) < minimumInterval) {
      return;
    }
    _lastPlayedAt[config.playerKey] = now;

    final audioSource = _sources[_resolveAssetPath(config)];
    if (audioSource == null) return;

    try {
      await SoLoud.instance.play(audioSource, volume: volume ?? config.volume);
    } catch (e) {
      debugPrint('[SOUND] Failed to play $sound: $e');
    }
  }

  Future<void> playHover({Object? source}) =>
      play(ServerAppSound.hover, source: source);

  Future<void> playPlayerJoinPop() => play(ServerAppSound.playerJoinPop);

  Future<void> playStartButton() => play(ServerAppSound.startButton);

  Future<void> playOptionsButton() => play(ServerAppSound.optionsButton);

  Future<void> playThemeSelect() => play(ServerAppSound.themeSelect);

  Future<void> playDropPlayer() => play(ServerAppSound.dropPlayer);

  String _resolveAssetPath(ServerAppSoundConfig config) {
    if (!config.randomizeAsset || config.assetPaths.length == 1) {
      return config.assetPaths.first;
    }
    return config.assetPaths[_random.nextInt(config.assetPaths.length)];
  }
}
