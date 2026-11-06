import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:realms/game/engine/engine.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Coordinates a play session and its persisted, one-time instructions.
final class PlayController extends ChangeNotifier {
  /// Randomness and tutorial storage can be supplied for deterministic tests.
  new({Random? random, PlayTutorialStore? tutorialStore})
    : _random = random ?? Random(),
      _tutorialStore = tutorialStore ?? _PreferencesPlayTutorialStore() {
    _state = GameState.start(
      configuration: GameConfiguration(),
      random: _random,
    );
    ready = _loadTutorial();
  }

  final Random _random;
  final PlayTutorialStore _tutorialStore;
  late GameState _state;
  GameBoard? _previousBoard;
  GameMoveResult? _lastMove;
  bool _tutorialLoaded = false;
  bool _showTutorial = false;
  bool _disposed = false;

  /// Completes after reading the tutorial preference, including read failures.
  late final Future<void> ready;

  /// The immutable engine snapshot for this session.
  GameState get state => _state;

  /// Board before the last successful move, for presentation animations.
  GameBoard? get previousBoard => _previousBoard;

  /// Engine events from the last successful move, for presentation animations.
  GameMoveResult? get lastMove => _lastMove;

  /// False while the persisted tutorial preference is being read.
  bool get tutorialLoaded => _tutorialLoaded;

  /// Whether the player must acknowledge the instructions.
  bool get showTutorial => _showTutorial;

  /// Input is accepted only after the tutorial and while the game is active.
  bool get canMove =>
      !_disposed &&
      _tutorialLoaded &&
      !_showTutorial &&
      _state.status == GameStatus.inProgress;

  Future<void> _loadTutorial() async {
    var showTutorial = true;

    try {
      showTutorial = !await _tutorialStore.hasSeenTutorial();
    } on Object catch (error) {
      debugPrint('Could not read the play tutorial preference: $error');
    }

    // A pending read must not resurrect a dismissed hint or a disposed screen.
    if (_disposed || _tutorialLoaded) return;

    _tutorialLoaded = true;
    _showTutorial = showTutorial;
    notifyListeners();
  }

  /// Hides the hint immediately, even if persistence is unavailable.
  Future<void> dismissTutorial() async {
    if (_disposed) return;

    _tutorialLoaded = true;
    _showTutorial = false;
    notifyListeners();

    try {
      await _tutorialStore.markTutorialSeen();
    } on Object catch (error) {
      debugPrint('Could not save the play tutorial preference: $error');
    }
  }

  /// Restarts with the same game configuration and random source.
  void startNewGame() {
    if (_disposed) return;

    _previousBoard = null;
    _lastMove = null;

    _state = GameState.start(
      configuration: _state.configuration,
      random: _random,
    );

    notifyListeners();
  }

  /// Delegates a player action to the engine, publishing only changed states.
  void move(MoveDirection direction) {
    if (!canMove) return;

    final result = _state.moveWithResult(direction: direction, random: _random);

    if (!result.changed) return;

    _previousBoard = _state.board;
    _lastMove = result;
    _state = result.state;

    notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}

/// Persists whether the player has acknowledged the play instructions.
///
/// An interface allows widget tests to use an in-memory implementation.
abstract interface class PlayTutorialStore {
  /// Whether the player already dismissed the tutorial.
  Future<bool> hasSeenTutorial();

  /// Remembers that the player dismissed the tutorial.
  Future<void> markTutorialSeen();
}

final class _PreferencesPlayTutorialStore implements PlayTutorialStore {
  static const _tutorialSeenKey = 'realms.play.tutorial_seen';

  late final SharedPreferencesAsync _preferences = SharedPreferencesAsync();

  @override
  Future<bool> hasSeenTutorial() async {
    return await _preferences.getBool(_tutorialSeenKey) ?? false;
  }

  @override
  Future<void> markTutorialSeen() {
    return _preferences.setBool(_tutorialSeenKey, true);
  }
}
