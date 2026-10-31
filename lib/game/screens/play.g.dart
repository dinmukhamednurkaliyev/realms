// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'play.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// Holds the current Classic game snapshot for the open play screen.

@ProviderFor(PlaySession)
final playSessionProvider = PlaySessionProvider._();

/// Holds the current Classic game snapshot for the open play screen.
final class PlaySessionProvider
    extends $NotifierProvider<PlaySession, GameState> {
  /// Holds the current Classic game snapshot for the open play screen.
  PlaySessionProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'playSessionProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$playSessionHash();

  @$internal
  @override
  PlaySession create() => PlaySession();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(GameState value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<GameState>(value),
    );
  }
}

String _$playSessionHash() => r'1ece875b9afdc66965c7f8b96318d84faaebf9c8';

/// Holds the current Classic game snapshot for the open play screen.

abstract class _$PlaySession extends $Notifier<GameState> {
  GameState build();
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref = this.ref as $Ref<GameState, GameState>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<GameState, GameState>,
              GameState,
              Object?,
              Object?
            >;
    return element.handleCreate(ref, build);
  }
}

/// Manages the one-time How to Play hint, independently of game rules.

@ProviderFor(PlayTutorial)
final playTutorialProvider = PlayTutorialProvider._();

/// Manages the one-time How to Play hint, independently of game rules.
final class PlayTutorialProvider
    extends $AsyncNotifierProvider<PlayTutorial, bool> {
  /// Manages the one-time How to Play hint, independently of game rules.
  PlayTutorialProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'playTutorialProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$playTutorialHash();

  @$internal
  @override
  PlayTutorial create() => PlayTutorial();
}

String _$playTutorialHash() => r'93bc289f946bcf2d9167b3e6d1acdb6c6b424bbb';

/// Manages the one-time How to Play hint, independently of game rules.

abstract class _$PlayTutorial extends $AsyncNotifier<bool> {
  FutureOr<bool> build();
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref = this.ref as $Ref<AsyncValue<bool>, bool>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<AsyncValue<bool>, bool>,
              AsyncValue<bool>,
              Object?,
              Object?
            >;
    return element.handleCreate(ref, build);
  }
}
