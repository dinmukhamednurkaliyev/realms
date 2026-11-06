import 'dart:async';

import 'package:flutter_soloud/flutter_soloud.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:realms/app/asset/asset.dart';
import 'package:realms/app/audio/audio.dart';

void main() {
  late _FakeSoLoud engine;
  late AppAudio audio;

  setUp(() {
    engine = _FakeSoLoud();
    audio = AppAudio(engine: engine);
  });
  tearDown(() => audio.dispose());

  test(
    'shares initialization and caches each asset across consumers',
    () async {
      final first = audio.initialize();
      final second = audio.initialize();
      expect(second, same(first));
      await first;
      await audio.initialize();
      expect(engine.initializations, 1);
      expect(engine.loaded, [
        assets.game.sounds.slide,
        assets.game.sounds.merge,
      ]);
      expect(audio.isAvailable, isTrue);
      audio
        ..play(SoundEffect.slide, volume: 0.18)
        ..play(SoundEffect.merge, volume: 0.34)
        ..play(SoundEffect.merge, volume: 0.42);
      expect(engine.played, [
        (path: assets.game.sounds.slide, volume: 0.18),
        (path: assets.game.sounds.merge, volume: 0.34),
        (path: assets.game.sounds.merge, volume: 0.42),
      ]);
    },
  );

  test('skips unavailable requests without replaying them later', () async {
    engine.initializationGate = Completer<void>();
    audio.play(SoundEffect.slide);
    final loading = audio.initialize();
    audio.play(SoundEffect.merge);
    expect(audio.isAvailable, isFalse);
    engine.initializationGate!.complete();
    await loading;
    expect(engine.played, isEmpty);
  });

  test('initialization failures are contained and can be retried', () async {
    engine.failInitialization = true;
    await audio.initialize();
    expect(audio.isAvailable, isFalse);
    expect(engine.loaded, isEmpty);
    engine.failInitialization = false;
    await audio.initialize();
    expect(audio.isAvailable, isTrue);
    expect(engine.initializations, 2);
  });

  test('failed assets retry without reloading successful assets', () async {
    engine.failedPaths.add(assets.game.sounds.merge);
    await audio.initialize();
    audio
      ..play(SoundEffect.slide)
      ..play(SoundEffect.merge);
    expect(engine.played, hasLength(1));
    engine.failedPaths.clear();
    await audio.initialize();
    audio.play(SoundEffect.merge);
    expect(
      engine.loaded.where((path) => path == assets.game.sounds.slide),
      hasLength(1),
    );
    expect(engine.played, hasLength(2));
    expect(engine.initializations, 1);
  });

  test('playback failures and invalid volumes never escape', () async {
    await audio.initialize();
    engine.failPlayback = true;
    expect(() => audio.play(SoundEffect.slide), returnsNormally);
    engine.failPlayback = false;
    for (final volume in [-0.1, 1.1, double.nan, double.infinity]) {
      audio.play(SoundEffect.slide, volume: volume);
    }
    expect(engine.played, isEmpty);
    audio.play(SoundEffect.slide);
    expect(engine.played, hasLength(1));
  });

  test('disposal before use does not initialize the engine', () async {
    await audio.dispose();
    await audio.initialize();
    audio.play(SoundEffect.slide);
    expect(engine.initializations, 0);
    expect(engine.shutdowns, 0);
    expect(engine.played, isEmpty);
  });

  test(
    'disposal during initialization waits and prevents further loading',
    () async {
      engine.initializationGate = Completer<void>();
      final loading = audio.initialize();
      final closing = audio.dispose();
      expect(audio.dispose(), same(closing));
      engine.initializationGate!.complete();
      await Future.wait([loading, closing]);
      expect(engine.loaded, isEmpty);
      expect(engine.shutdowns, 1);
      expect(audio.isAvailable, isFalse);
    },
  );

  test(
    'disposal waits for late sources and releases them exactly once',
    () async {
      engine.loadGate = Completer<void>();
      final loading = audio.initialize();
      await engine.loadingStarted.future;
      final closing = audio.dispose();
      audio.play(SoundEffect.slide);
      engine.loadGate!.complete();
      await Future.wait([loading, closing]);
      expect(engine.loaded, [assets.game.sounds.slide]);
      expect(engine.released, [assets.game.sounds.slide]);
      expect(engine.shutdowns, 1);
      expect(engine.played, isEmpty);
    },
  );

  test(
    'release failures do not prevent remaining cleanup or shutdown',
    () async {
      await audio.initialize();
      engine
        ..failRelease = true
        ..failShutdown = true;
      await audio.dispose();
      await audio.dispose();
      expect(engine.released, hasLength(2));
      expect(engine.shutdowns, 1);
      expect(audio.isAvailable, isFalse);
      audio.play(SoundEffect.slide);
      expect(engine.played, isEmpty);
    },
  );

  test(
    'another owner cannot reset or dispose an active shared engine',
    () async {
      await audio.initialize();
      final other = AppAudio(engine: engine);
      await other.initialize();
      expect(other.isAvailable, isFalse);
      await other.dispose();
      audio.play(SoundEffect.slide);
      expect(engine.initializations, 1);
      expect(engine.shutdowns, 0);
      expect(engine.released, isEmpty);
      expect(engine.played, hasLength(1));
    },
  );

  test(
    'a replacement waits for the previous owner to finish shutdown',
    () async {
      await audio.initialize();
      engine.shutdownGate = Completer<void>();
      final closing = audio.dispose();
      final replacement = AppAudio(engine: engine);
      addTearDown(replacement.dispose);
      final loading = replacement.initialize();
      await engine.shutdownStarted.future;
      expect(engine.initializations, 1);
      engine.shutdownGate!.complete();
      await Future.wait([loading, closing]);
      expect(engine.initializations, 2);
      expect(replacement.isAvailable, isTrue);
      replacement.play(SoundEffect.slide);
      expect(engine.played, hasLength(1));
    },
  );

  test(
    'does not claim an engine initialized outside application ownership',
    () async {
      engine.initialized = true;
      await audio.initialize();
      await audio.dispose();
      expect(engine.initializations, 0);
      expect(engine.shutdowns, 0);
    },
  );
}

final class _FakeSource implements AudioSource {
  new(this.path);
  final String path;
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

// Emulates only the platform operations used by AppAudio; no native handles or
// AudioSource constructors are used, so tests never require an audio device.
final class _FakeSoLoud implements SoLoud {
  bool initialized = false;
  int initializations = 0;
  int shutdowns = 0;
  bool failInitialization = false;
  bool failPlayback = false;
  bool failRelease = false;
  bool failShutdown = false;
  final failedPaths = <String>{};
  final loaded = <String>[];
  final released = <String>[];
  final played = <({String path, double volume})>[];
  Completer<void>? initializationGate;
  Completer<void>? loadGate;
  Completer<void>? shutdownGate;
  final loadingStarted = Completer<void>();
  final shutdownStarted = Completer<void>();

  Future<void> _initialize() async {
    initializations++;
    await initializationGate?.future;
    if (failInitialization) throw StateError('No device');
    initialized = true;
  }

  Future<AudioSource> _load(String path) async {
    loaded.add(path);
    if (!loadingStarted.isCompleted) loadingStarted.complete();
    await loadGate?.future;
    if (failedPaths.contains(path)) throw StateError('Cannot load asset');
    return _FakeSource(path);
  }

  Future<void> _release(AudioSource source) async {
    released.add((source as _FakeSource).path);
    if (failRelease) throw StateError('Cannot release source');
  }

  Future<void> _shutdown() async {
    shutdowns++;
    if (!shutdownStarted.isCompleted) shutdownStarted.complete();
    await shutdownGate?.future;
    initialized = false;
    if (failShutdown) throw StateError('Cannot shut down');
  }

  @override
  dynamic noSuchMethod(Invocation invocation) {
    switch (invocation.memberName) {
      case #isInitialized:
        return initialized;
      case #init:
        return _initialize();
      case #loadAsset:
        return _load(invocation.positionalArguments.single as String);
      case #play:
        if (failPlayback) throw StateError('Playback failed');
        played.add((
          path: (invocation.positionalArguments.single as _FakeSource).path,
          volume: invocation.namedArguments[#volume]! as double,
        ));
        return const SoundHandle(1);
      case #disposeSource:
        return _release(invocation.positionalArguments.single as AudioSource);
      case #deinitAsync:
        return _shutdown();
    }
    return super.noSuchMethod(invocation);
  }
}
