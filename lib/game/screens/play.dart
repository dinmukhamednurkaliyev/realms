import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:realms/app/localization/localization.dart';
import 'package:realms/game/engine/engine.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'board.dart';
import 'sounds.dart';

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

/// Displays a Classic game with touch, keyboard, and sound feedback.
final class PlayScreen extends StatefulWidget {
  /// Creates the Classic game screen.
  const new({this.controller, super.key});

  /// An optional externally owned session; otherwise the screen owns one.
  final PlayController? controller;

  @override
  State<PlayScreen> createState() => _PlayScreenState();
}

final class _PlayScreenState extends State<PlayScreen>
    with SingleTickerProviderStateMixin {
  static const double _minimumSwipeDistance = 30;

  final FocusNode _focusNode = FocusNode(debugLabel: 'Realms play controls');

  Offset _panDistance = Offset.zero;

  late PlayController _controller;
  late final AnimationController _boardAnimation;
  late final PlaySounds _sounds;
  late GameState _observedState;

  bool _mergeSoundPlayed = false;

  void _onAnimationFrame() {
    final move = _controller.lastMove;

    // Play the merge effect once, when the sliding phase has finished.
    if (!_mergeSoundPlayed &&
        _boardAnimation.isAnimating &&
        _boardAnimation.value >= PlayBoard.slideEnd &&
        move != null &&
        move.merges.isNotEmpty) {
      _mergeSoundPlayed = true;

      _sounds.play(PlaySoundEffect.merge, mergeCount: move.merges.length);
    }

    if (mounted) setState(() {});
  }

  void _onAnimationStatus(AnimationStatus status) {
    if (status == AnimationStatus.completed && mounted) {
      setState(() {});
    }
  }

  @override
  void initState() {
    super.initState();

    _controller = widget.controller ?? PlayController();
    _observedState = _controller.state;

    // Preload audio without blocking the game screen.
    _sounds = PlaySounds();
    unawaited(_sounds.initialize());

    _boardAnimation =
        AnimationController(
            vsync: this,
            duration: const Duration(milliseconds: 240),
            value: 1,
          )
          ..addListener(_onAnimationFrame)
          ..addStatusListener(_onAnimationStatus);

    _controller.addListener(_onChanged);
  }

  void _onChanged() {
    final nextState = _controller.state;

    if (!identical(_observedState, nextState)) {
      _observedState = nextState;

      if (_controller.lastMove != null) {
        // A new move starts a new sound and animation sequence.
        _mergeSoundPlayed = false;

        _sounds.play(PlaySoundEffect.slide);
        _boardAnimation.forward(from: 0);
      } else {
        // Restart cancels the previous animation and its pending merge.
        _mergeSoundPlayed = false;
        _boardAnimation.value = 1;
      }
    }

    if (mounted) setState(() {});
  }

  @override
  void didUpdateWidget(PlayScreen oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (oldWidget.controller == widget.controller) return;

    _controller.removeListener(_onChanged);

    if (oldWidget.controller == null) {
      _controller.dispose();
    }

    _controller = widget.controller ?? PlayController();
    _observedState = _controller.state;
    _mergeSoundPlayed = false;

    // The updated controller starts from its current snapshot, without a tween.
    _boardAnimation.removeListener(_onAnimationFrame);
    _boardAnimation.removeStatusListener(_onAnimationStatus);

    _boardAnimation.value = 1;

    _boardAnimation.addListener(_onAnimationFrame);
    _boardAnimation.addStatusListener(_onAnimationStatus);

    _controller.addListener(_onChanged);
  }

  @override
  void dispose() {
    _controller.removeListener(_onChanged);

    if (widget.controller == null) {
      _controller.dispose();
    }

    _boardAnimation.removeListener(_onAnimationFrame);
    _boardAnimation.removeStatusListener(_onAnimationStatus);
    _boardAnimation.dispose();

    // Release this screen's sounds without shutting down the shared engine.
    unawaited(_sounds.dispose());

    _focusNode.dispose();

    super.dispose();
  }

  KeyEventResult _handleKeyEvent(KeyEvent event, {required bool canMove}) {
    // Ignore key repeats to ensure a held key does not produce extra moves.
    if (event is! KeyDownEvent) {
      return KeyEventResult.ignored;
    }

    // Leave operating-system and application shortcuts untouched.
    final keyboard = HardwareKeyboard.instance;

    if (keyboard.isControlPressed ||
        keyboard.isAltPressed ||
        keyboard.isMetaPressed) {
      return KeyEventResult.ignored;
    }

    final direction = switch (event.logicalKey) {
      LogicalKeyboardKey.arrowLeft ||
      LogicalKeyboardKey.keyA => MoveDirection.left,

      LogicalKeyboardKey.arrowRight ||
      LogicalKeyboardKey.keyD => MoveDirection.right,

      LogicalKeyboardKey.arrowUp || LogicalKeyboardKey.keyW => MoveDirection.up,

      LogicalKeyboardKey.arrowDown ||
      LogicalKeyboardKey.keyS => MoveDirection.down,

      _ => null,
    };

    if (direction == null) {
      return KeyEventResult.ignored;
    }

    if (canMove) {
      _controller.move(direction);
    }

    return KeyEventResult.handled;
  }

  void _handlePanEnd(bool canMove) {
    final distance = _panDistance;
    _panDistance = Offset.zero;

    if (!canMove) {
      return;
    }

    final horizontal = distance.dx.abs();
    final vertical = distance.dy.abs();

    if (max(horizontal, vertical) < _minimumSwipeDistance) {
      return;
    }

    final direction = horizontal >= vertical
        ? (distance.dx < 0 ? MoveDirection.left : MoveDirection.right)
        : (distance.dy < 0 ? MoveDirection.up : MoveDirection.down);

    _controller.move(direction);
  }

  Future<void> _dismissTutorial() async {
    await _controller.dismissTutorial();

    if (mounted) {
      _focusNode.requestFocus();
    }
  }

  @override
  Widget build(BuildContext context) {
    final localization = AppLocalization.of(context).game;
    final gameState = _controller.state;
    final showTutorial = _controller.showTutorial;

    final canMove = _controller.canMove && !_boardAnimation.isAnimating;

    final board = gameState.board;

    return Focus(
      focusNode: _focusNode,
      autofocus: true,
      onKeyEvent: (node, event) => _handleKeyEvent(event, canMove: canMove),
      child: Scaffold(
        appBar: AppBar(
          title: Text(localization.classicMode),
          actions: [
            IconButton(
              onPressed: () => _controller.startNewGame(),
              tooltip: localization.newGame,
              icon: const Icon(Icons.refresh),
            ),
          ],
        ),
        body: Stack(
          children: [
            SafeArea(
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 500),
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      children: [
                        Text(localization.scoreLabel),
                        Text(
                          localization.score(points: gameState.score),
                          style: Theme.of(context).textTheme.headlineLarge,
                        ),
                        const SizedBox(height: 20),
                        Expanded(
                          child: Center(
                            child: GestureDetector(
                              key: const ValueKey('play_board'),
                              behavior: HitTestBehavior.opaque,
                              onPanStart: canMove
                                  ? (details) => _panDistance = Offset.zero
                                  : null,
                              onPanUpdate: canMove
                                  ? (details) => _panDistance += details.delta
                                  : null,
                              onPanCancel: canMove
                                  ? () => _panDistance = Offset.zero
                                  : null,
                              onPanEnd: canMove
                                  ? (details) => _handlePanEnd(canMove)
                                  : null,
                              child: PlayBoard(
                                board: board,
                                previousBoard: _controller.previousBoard,
                                lastMove: _controller.lastMove,
                                progress: _boardAnimation.value,
                              ),
                            ),
                          ),
                        ),
                        if (gameState.status == GameStatus.won)
                          Text(localization.youWon)
                        else if (gameState.status == GameStatus.lost)
                          Text(localization.gameOver),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            if (showTutorial) ...[
              const Positioned.fill(
                child: ModalBarrier(
                  dismissible: false,
                  color: Color(0x99000000),
                ),
              ),
              Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 360),
                    child: Card(
                      child: Padding(
                        padding: const EdgeInsets.all(24),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.touch_app_outlined, size: 52),
                            const SizedBox(height: 16),
                            Text(
                              localization.howToPlayTitle,
                              style: Theme.of(context).textTheme.headlineSmall,
                            ),
                            const SizedBox(height: 12),
                            Text(
                              localization.howToPlayDescription,
                              textAlign: TextAlign.center,
                            ),
                            const SizedBox(height: 8),
                            Text(
                              localization.howToPlayKeyboard,
                              textAlign: TextAlign.center,
                              style: Theme.of(context).textTheme.bodySmall,
                            ),
                            const SizedBox(height: 24),
                            SizedBox(
                              width: double.infinity,
                              child: FilledButton(
                                onPressed: _dismissTutorial,
                                child: Text(localization.gotIt),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
