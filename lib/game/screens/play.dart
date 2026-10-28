import 'package:flutter/material.dart';
import 'package:realms/app/localization/localization.dart' as localization;

import '../engine/mechanics.dart' as mechanics;

/// Displays and controls a Classic game of Realms.
///
/// Tile levels are displayed as numbers until building artwork is available.
/// The game engine determines all board changes.
final class PlayScreen extends StatefulWidget {
  /// Creates the Classic game screen.
  const new({super.key});

  @override
  State<PlayScreen> createState() => _PlayScreenState();
}

final class _PlayScreenState extends State<PlayScreen> {
  late final PlayController _controller;

  @override
  void initState() {
    super.initState();
    _controller = PlayController();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final strings = localization.Strings.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(strings.classicMode),
        actions: [
          IconButton(
            onPressed: _controller.startNewGame,
            tooltip: strings.newGame,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 500),
            child: ListenableBuilder(
              listenable: _controller,
              builder: (context, child) {
                final state = _controller.state;
                final board = state.board;
                final colorScheme = Theme.of(context).colorScheme;

                return SingleChildScrollView(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(strings.scoreLabel),
                      Text(
                        '${state.score}',
                        style: Theme.of(context).textTheme.headlineLarge,
                      ),
                      const SizedBox(height: 24),
                      AspectRatio(
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
                        state.isGameOver ? strings.gameOver : strings.moveHint,
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 12),
                      Wrap(
                        alignment: WrapAlignment.center,
                        spacing: 12,
                        children: [
                          IconButton.filledTonal(
                            tooltip: strings.moveLeft,
                            onPressed: () =>
                                _controller.move(mechanics.MoveDirection.left),
                            icon: const Icon(Icons.arrow_back),
                          ),
                          IconButton.filledTonal(
                            tooltip: strings.moveUp,
                            onPressed: () =>
                                _controller.move(mechanics.MoveDirection.up),
                            icon: const Icon(Icons.arrow_upward),
                          ),
                          IconButton.filledTonal(
                            tooltip: strings.moveDown,
                            onPressed: () =>
                                _controller.move(mechanics.MoveDirection.down),
                            icon: const Icon(Icons.arrow_downward),
                          ),
                          IconButton.filledTonal(
                            tooltip: strings.moveRight,
                            onPressed: () =>
                                _controller.move(mechanics.MoveDirection.right),
                            icon: const Icon(Icons.arrow_forward),
                          ),
                        ],
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}
