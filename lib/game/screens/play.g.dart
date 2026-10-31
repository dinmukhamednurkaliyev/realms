// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'play.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// Manages the Classic game session displayed by [PlayScreen].
///
/// The engine owns the rules; this notifier owns only the current snapshot
/// and the random source. It is automatically disposed when unused.

@ProviderFor(PlaySession)
final playSessionProvider = PlaySessionProvider._();

/// Manages the Classic game session displayed by [PlayScreen].
///
/// The engine owns the rules; this notifier owns only the current snapshot
/// and the random source. It is automatically disposed when unused.
final class PlaySessionProvider
    extends $NotifierProvider<PlaySession, GameState> {
  /// Manages the Classic game session displayed by [PlayScreen].
  ///
  /// The engine owns the rules; this notifier owns only the current snapshot
  /// and the random source. It is automatically disposed when unused.
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

/// Manages the Classic game session displayed by [PlayScreen].
///
/// The engine owns the rules; this notifier owns only the current snapshot
/// and the random source. It is automatically disposed when unused.

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
