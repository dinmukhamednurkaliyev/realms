import 'package:flutter/foundation.dart';
import 'package:flutter_soloud/flutter_soloud.dart';
import 'package:realms/app/assets/assets.dart';

/// Sound effects for the Classic game.
enum PlaySoundEffect {
  /// A successful move begins.
  slide,

  /// One or more tiles merge.
  merge,
}

/// Manages the sound effects used by one game screen.
///
/// Audio failures do not interrupt gameplay.
final class PlaySounds {
  /// Creates a sound manager for one play screen.
  new();

  static Future<void>? _engineInitialization;

  final SoLoud _engine = SoLoud.instance;
  final Map<PlaySoundEffect, AudioSource> _sources = {};

  Future<void>? _loading;
  bool _disposed = false;

  static void _log(String message) {
    if (kDebugMode) {
      debugPrint('[Realms Audio] $message');
    }
  }

  /// Initializes audio and preloads the sound effects.
  Future<void> initialize() => _loading ??= _load();

  static Future<void> _ensureEngineInitialized() {
    if (SoLoud.instance.isInitialized) {
      return Future<void>.value();
    }

    return _engineInitialization ??= _initializeEngine();
  }

  static Future<void> _initializeEngine() async {
    try {
      await SoLoud.instance.init();
    } finally {
      _engineInitialization = null;
    }
  }

  Future<void> _load() async {
    _log('Initializing audio engine...');

    try {
      await _ensureEngineInitialized();
      _log('Engine initialized.');
      _log('Device: ${_engine.getAudioDeviceState()}');
    } on Object catch (error) {
      _log('Engine initialization failed: $error');
      return;
    }

    final paths = <PlaySoundEffect, String>{
      PlaySoundEffect.slide: assets.game.sounds.slide,
      PlaySoundEffect.merge: assets.game.sounds.merge,
    };

    for (final entry in paths.entries) {
      if (_disposed) {
        return;
      }

      try {
        _log('Loading ${entry.key.name}: ${entry.value}');

        final source = await _engine.loadAsset(entry.value);

        if (_disposed) {
          await _engine.disposeSource(source);
          return;
        }

        _sources[entry.key] = source;

        _log(
          'Loaded ${entry.key.name}, '
          'duration: ${_engine.getLength(source)}',
        );
      } on Object catch (error) {
        _log('Failed to load ${entry.key.name}: $error');
      }
    }

    _log('Audio loading completed: ${_sources.length}/2 sounds.');
  }

  /// Plays a preloaded effect without blocking gameplay.
  void play(PlaySoundEffect effect, {int mergeCount = 1}) {
    if (_disposed) {
      return;
    }

    if (!_engine.isInitialized) {
      _log('Cannot play ${effect.name}: engine not initialized.');
      return;
    }

    final source = _sources[effect];

    if (source == null) {
      _log('Cannot play ${effect.name}: sound not loaded.');
      return;
    }

    // Full volume during debugging to distinguish quiet files from failures.
    final volume = kDebugMode
        ? 1.0
        : switch (effect) {
            PlaySoundEffect.slide => 0.18,
            PlaySoundEffect.merge => mergeCount > 1 ? 0.42 : 0.34,
          };

    try {
      final handle = _engine.play(source, volume: volume);

      _log(
        'Playing ${effect.name}: '
        'handle=$handle, volume=$volume, '
        'device=${_engine.getAudioDeviceState()}',
      );
    } on Object catch (error) {
      _log('Failed to play ${effect.name}: $error');
    }
  }

  /// Releases this screen's loaded sounds.
  Future<void> dispose() async {
    if (_disposed) {
      return;
    }

    _disposed = true;
    await _loading;

    for (final source in _sources.values) {
      try {
        await _engine.disposeSource(source);
      } on Object catch (error) {
        _log('Failed to release a sound: $error');
      }
    }

    _sources.clear();
  }
}
