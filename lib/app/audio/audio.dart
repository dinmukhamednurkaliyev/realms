import 'package:flutter/foundation.dart';
import 'package:flutter_soloud/flutter_soloud.dart';
import 'package:realms/app/asset/asset.dart';

/// Existing, preloaded sound effects. Selection and timing belong to consumers.
enum SoundEffect {
  /// The sliding sound asset.
  slide,

  /// The merging sound asset.
  merge,
}

/// Playback access shared by presentation consumers, without teardown rights.
abstract interface class AudioPlayback {
  /// Preloads effects without blocking interaction; repeated calls are safe.
  Future<void> initialize();

  /// Requests immediate playback; unavailable effects are never queued.
  void play(SoundEffect effect, {double volume = 1});
}

/// Application-owned SoLoud resources, shared across routes.
///
/// Create one owner at application composition and pass [AudioPlayback] to
/// consumers. Disposal closes this owner permanently. Initialization can retry
/// failures, but never resets an engine owned by another instance.
final class AppAudio implements AudioPlayback {
  /// The engine can be replaced in tests without opening an audio device.
  new({this._engine});

  // Serializes ownership handoff when a new root replaces a disposing root.
  // This also prevents accidental duplicate owners of the native singleton.
  static final _owners = Map<SoLoud, AppAudio>.identity();

  SoLoud? _engine;
  final _sources = <SoundEffect, AudioSource>{};
  Future<void>? _loading;
  Future<void>? _closing;
  bool _initialized = false;
  bool _disposed = false;

  /// Whether at least one preloaded effect is currently available.
  bool get isAvailable => !_disposed && _sources.isNotEmpty;

  static void _log(String operation, Object error) {
    if (kDebugMode) debugPrint('Audio $operation failed: $error');
  }

  @override
  Future<void> initialize() {
    if (_disposed) return Future<void>.value();
    return _loading ??= _load().whenComplete(() => _loading = null);
  }

  Future<void> _load() async {
    try {
      final engine = _engine ??= SoLoud.instance;
      if (!_initialized) {
        final previousOwner = _owners[engine];
        if (previousOwner != null && !identical(previousOwner, this)) {
          if (!previousOwner._disposed) {
            throw StateError('Share the existing AppAudio with consumers.');
          }
          await previousOwner.dispose();
        }
        if (_disposed) return;
        // Another waiting owner may have acquired the engine while we awaited.
        final owner = _owners[engine];
        if (owner != null && !identical(owner, this)) {
          throw StateError('The audio engine already has an owner.');
        }
        if (engine.isInitialized) {
          throw StateError(
            'The audio engine was initialized outside AppAudio.',
          );
        }
        _owners[engine] = this;
        await engine.init();
        _initialized = true;
      }
      for (final effect in SoundEffect.values) {
        if (_disposed) return;
        if (_sources.containsKey(effect)) continue;
        final path = switch (effect) {
          SoundEffect.slide => assets.game.sounds.slide,
          SoundEffect.merge => assets.game.sounds.merge,
        };
        try {
          // Retain even a late load so the owning disposal releases it once.
          _sources[effect] = await engine.loadAsset(path);
        } on Object catch (error) {
          _log('loading ${effect.name}', error);
        }
      }
    } on Object catch (error) {
      _log('initialization', error);
    }
  }

  @override
  void play(SoundEffect effect, {double volume = 1}) {
    final engine = _engine;
    if (_disposed || !_initialized || engine == null) return;
    final source = _sources[effect];
    if (source == null) return;
    if (!volume.isFinite || volume < 0 || volume > 1) {
      _log('playback', ArgumentError.value(volume, 'volume', 'Expected 0–1'));
      return;
    }
    try {
      engine.play(source, volume: volume);
    } on Object catch (error) {
      _log('playback', error);
    }
  }

  /// Waits for in-flight loading, releases sources, then shuts down our engine.
  ///
  /// Safe to call repeatedly or while initialization is still pending.
  Future<void> dispose() {
    _disposed = true;
    return _closing ??= _close();
  }

  Future<void> _close() async {
    await _loading;
    final engine = _engine;
    if (engine == null) return;
    try {
      for (final source in _sources.values) {
        try {
          await engine.disposeSource(source);
        } on Object catch (error) {
          _log('source disposal', error);
        }
      }
      _sources.clear();
      if (identical(_owners[engine], this)) {
        try {
          await engine.deinitAsync();
        } on Object catch (error) {
          _log('shutdown', error);
        }
      }
    } finally {
      _initialized = false;
      if (identical(_owners[engine], this)) _owners.remove(engine);
    }
  }
}
