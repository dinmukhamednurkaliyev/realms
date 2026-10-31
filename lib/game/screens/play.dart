import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:realms/app/localization/localization.dart';
import 'package:realms/game/engine/engine.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:shared_preferences/shared_preferences.dart';

part 'play.g.dart';

/// Holds the current Classic game snapshot for the open play screen.
@riverpod
class PlaySession extends _$PlaySession {
  final Random _random = Random();

  /// Starts a new game when the session is first observed.
  @override
  GameState build() {
    return GameState.start(configuration: GameConfiguration(), random: _random);
  }

  /// Restarts the game with the same configuration.
  void startNewGame() {
    state = GameState.start(
      configuration: state.configuration,
      random: _random,
    );
  }

  /// Applies a direction only while the game is in progress.
  void move(MoveDirection direction) {
    if (state.status != GameStatus.inProgress) {
      return;
    }

    final result = state.moveWithResult(direction: direction, random: _random);

    if (result.changed) {
      state = result.state;
    }
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
  final SharedPreferencesAsync _preferences = SharedPreferencesAsync();

  @override
  Future<bool> hasSeenTutorial() async {
    return await _preferences.getBool(_tutorialSeenKey) ?? false;
  }

  @override
  Future<void> markTutorialSeen() {
    return _preferences.setBool(_tutorialSeenKey, true);
  }
}

/// Storage is replaceable in tests; it is not exported from the Game feature.
final playTutorialStoreProvider = Provider<PlayTutorialStore>(
  (ref) => _PreferencesPlayTutorialStore(),
);

/// Manages the one-time How to Play hint, independently of game rules.
@riverpod
class PlayTutorial extends _$PlayTutorial {
  /// Reads the persisted acknowledgment when the screen first opens.
  @override
  Future<bool> build() async {
    try {
      return !await ref.read(playTutorialStoreProvider).hasSeenTutorial();
    } on Exception catch (error) {
      debugPrint('Could not read the play tutorial preference: $error');
      return true;
    }
  }

  /// Hides the hint immediately and persists the acknowledgment.
  Future<void> dismiss() async {
    state = const AsyncData(false);

    try {
      await ref.read(playTutorialStoreProvider).markTutorialSeen();
    } on Exception catch (error) {
      debugPrint('Could not save the play tutorial preference: $error');
    }
  }
}

/// Displays a Classic game with touch and keyboard controls.
final class PlayScreen extends ConsumerStatefulWidget {
  /// Creates the Classic game screen.
  const new({super.key});

  @override
  ConsumerState<PlayScreen> createState() => _PlayScreenState();
}

final class _PlayScreenState extends ConsumerState<PlayScreen> {
  static const double _minimumSwipeDistance = 30;

  final FocusNode _focusNode = FocusNode(debugLabel: 'Realms play controls');
  Offset _panDistance = Offset.zero;

  @override
  void dispose() {
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
      ref.read(playSessionProvider.notifier).move(direction);
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

    ref.read(playSessionProvider.notifier).move(direction);
  }

  Future<void> _dismissTutorial() async {
    await ref.read(playTutorialProvider.notifier).dismiss();
    if (mounted) {
      _focusNode.requestFocus();
    }
  }

  @override
  Widget build(BuildContext context) {
    final strings = Strings.of(context);
    final gameState = ref.watch(playSessionProvider);
    final tutorial = ref.watch(playTutorialProvider);
    final showTutorial = tutorial.when(
      data: (visible) => visible,
      loading: () => false,
      error: (error, stackTrace) => true,
    );
    final canMove =
        tutorial is AsyncData<bool> &&
        !tutorial.value &&
        gameState.status == GameStatus.inProgress;
    final board = gameState.board;
    final colorScheme = Theme.of(context).colorScheme;

    return Focus(
      focusNode: _focusNode,
      autofocus: true,
      onKeyEvent: (node, event) => _handleKeyEvent(event, canMove: canMove),
      child: Scaffold(
        appBar: AppBar(
          title: Text(strings.classicMode),
          actions: [
            IconButton(
              onPressed: () =>
                  ref.read(playSessionProvider.notifier).startNewGame(),
              tooltip: strings.newGame,
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
                        Text(strings.scoreLabel),
                        Text(
                          '${gameState.score}',
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
                              child: AspectRatio(
                                aspectRatio: board.columnCount / board.rowCount,
                                child: GridView.builder(
                                  physics: const NeverScrollableScrollPhysics(),
                                  itemCount: board.rowCount * board.columnCount,
                                  gridDelegate:
                                      SliverGridDelegateWithFixedCrossAxisCount(
                                        crossAxisCount: board.columnCount,
                                        mainAxisSpacing: 8,
                                        crossAxisSpacing: 8,
                                      ),
                                  itemBuilder: (context, index) {
                                    final rowIndex = index ~/ board.columnCount;
                                    final columnIndex =
                                        index % board.columnCount;
                                    final tileLevel = board.tileAt(
                                      rowIndex: rowIndex,
                                      columnIndex: columnIndex,
                                    );

                                    return DecoratedBox(
                                      key: ValueKey('board_cell_$index'),
                                      decoration: BoxDecoration(
                                        color: tileLevel == null
                                            ? colorScheme
                                                  .surfaceContainerHighest
                                            : colorScheme.primaryContainer,
                                        borderRadius: BorderRadius.circular(10),
                                      ),
                                      child: Center(
                                        child: Text(
                                          tileLevel?.toString() ?? '',
                                          style: Theme.of(context)
                                              .textTheme
                                              .titleLarge,
                                        ),
                                      ),
                                    );
                                  },
                                ),
                              ),
                            ),
                          ),
                        ),
                        if (gameState.status == GameStatus.won)
                          Text(strings.youWon)
                        else if (gameState.status == GameStatus.lost)
                          Text(strings.gameOver),
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
                              strings.howToPlayTitle,
                              style: Theme.of(context).textTheme.headlineSmall,
                            ),
                            const SizedBox(height: 12),
                            Text(
                              strings.howToPlayDescription,
                              textAlign: TextAlign.center,
                            ),
                            const SizedBox(height: 8),
                            Text(
                              strings.howToPlayKeyboard,
                              textAlign: TextAlign.center,
                              style: Theme.of(context).textTheme.bodySmall,
                            ),
                            const SizedBox(height: 24),
                            SizedBox(
                              width: double.infinity,
                              child: FilledButton(
                                onPressed: _dismissTutorial,
                                child: Text(strings.gotIt),
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
