import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:realms/app/localization/localization.dart';
import 'package:realms/game/engine/engine.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'play.g.dart';

/// Manages the Classic game session displayed by [PlayScreen].
///
/// The engine owns the rules; this notifier owns only the current snapshot
/// and the random source. It is automatically disposed when unused.
@riverpod
class PlaySession extends _$PlaySession {
  final Random _random = Random();

  /// Creates a fresh Classic game when the session is first observed.
  @override
  GameState build() {
    return GameState.start(configuration: GameConfiguration(), random: _random);
  }

  /// Restarts the session using the current configuration.
  void startNewGame() {
    state = GameState.start(
      configuration: state.configuration,
      random: _random,
    );
  }

  /// Applies a legal move and publishes a new snapshot only when it changes.
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

/// Displays a Classic game of Realms.
///
/// The session provider is kept in this file because it is used only by
/// this screen, and the Game feature exports just [PlayScreen].
final class PlayScreen extends ConsumerWidget {
  /// Creates the Classic game screen.
  const new({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final strings = Strings.of(context);
    final gameState = ref.watch(playSessionProvider);
    final session = ref.read(playSessionProvider.notifier);
    final board = gameState.board;
    final colorScheme = Theme.of(context).colorScheme;
    final canMove = gameState.status == GameStatus.inProgress;

    return Scaffold(
      appBar: AppBar(
        title: Text(strings.classicMode),
        actions: [
          IconButton(
            onPressed: session.startNewGame,
            tooltip: strings.newGame,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 500),
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(strings.scoreLabel),
                  Text(
                    '${gameState.score}',
                    style: Theme.of(context).textTheme.headlineLarge,
                  ),
                  const SizedBox(height: 24),
                  AspectRatio(
                    aspectRatio: board.columnCount / board.rowCount,
                    child: GridView.builder(
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: board.rowCount * board.columnCount,
                      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: board.columnCount,
                        mainAxisSpacing: 8,
                        crossAxisSpacing: 8,
                      ),
                      itemBuilder: (context, index) {
                        final rowIndex = index ~/ board.columnCount;
                        final columnIndex = index % board.columnCount;
                        final tileLevel = board.tileAt(
                          rowIndex: rowIndex,
                          columnIndex: columnIndex,
                        );

                        return DecoratedBox(
                          key: ValueKey('board_cell_$index'),
                          decoration: BoxDecoration(
                            color: tileLevel == null
                                ? colorScheme.surfaceContainerHighest
                                : colorScheme.primaryContainer,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Center(
                            child: Text(
                              tileLevel?.toString() ?? '',
                              style: Theme.of(context).textTheme.titleLarge,
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    gameState.isGameOver ? strings.gameOver : strings.moveHint,
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 12),
                  Wrap(
                    alignment: WrapAlignment.center,
                    spacing: 12,
                    children: [
                      IconButton.filledTonal(
                        tooltip: strings.moveLeft,
                        onPressed: canMove
                            ? () => session.move(MoveDirection.left)
                            : null,
                        icon: const Icon(Icons.arrow_back),
                      ),
                      IconButton.filledTonal(
                        tooltip: strings.moveUp,
                        onPressed: canMove
                            ? () => session.move(MoveDirection.up)
                            : null,
                        icon: const Icon(Icons.arrow_upward),
                      ),
                      IconButton.filledTonal(
                        tooltip: strings.moveDown,
                        onPressed: canMove
                            ? () => session.move(MoveDirection.down)
                            : null,
                        icon: const Icon(Icons.arrow_downward),
                      ),
                      IconButton.filledTonal(
                        tooltip: strings.moveRight,
                        onPressed: canMove
                            ? () => session.move(MoveDirection.right)
                            : null,
                        icon: const Icon(Icons.arrow_forward),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
