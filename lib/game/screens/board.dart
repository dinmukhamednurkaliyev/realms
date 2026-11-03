import 'package:flutter/material.dart';
import 'package:realms/game/engine/engine.dart';

/// Draws a game board and the movement, merge, and spawn phases of one move.
///
/// Positions are derived entirely from engine events. This widget never
/// calculates gameplay rules or changes the current game snapshot.
final class PlayBoard extends StatelessWidget {
  /// Creates a board presentation for the given snapshot and animation.
  const new({
    required this.board,
    required this.previousBoard,
    required this.lastMove,
    required this.progress,
    super.key,
  });

  /// The resulting board to display at the end of the animation.
  final GameBoard board;

  /// The board before the last successful move, or `null` if idle.
  final GameBoard? previousBoard;

  /// The engine events used to animate the latest move, or `null` if idle.
  final GameMoveResult? lastMove;

  /// Normalized animation progress from zero (old board) to one (new board).
  final double progress;

  static const double _spacing = 8;
  static const double _slideEnd = 0.60;
  static const double _spawnStart = 0.80;

  static double _fraction(double value, double start, double end) {
    if (value <= start) return 0;
    if (value >= end) return 1;
    return (value - start) / (end - start);
  }

  @override
  Widget build(BuildContext context) {
    final previous = previousBoard;
    final move = lastMove;
    final animating = previous != null && move != null && progress < 1;
    final theme = Theme.of(context);

    return AspectRatio(
      aspectRatio: board.columnCount / board.rowCount,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final cellWidth =
              (constraints.maxWidth - _spacing * (board.columnCount - 1)) /
              board.columnCount;
          final cellHeight =
              (constraints.maxHeight - _spacing * (board.rowCount - 1)) /
              board.rowCount;

          Offset offset(BoardPosition position) => Offset(
            position.columnIndex * (cellWidth + _spacing),
            position.rowIndex * (cellHeight + _spacing),
          );

          Widget tile({
            required BoardPosition position,
            required int level,
            required String identifier,
            double scale = 1,
            Offset? location,
          }) {
            final target = location ?? offset(position);
            return Positioned(
              left: target.dx,
              top: target.dy,
              width: cellWidth,
              height: cellHeight,
              child: Transform.scale(
                scale: scale,
                child: DecoratedBox(
                  key: ValueKey(identifier),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.primaryContainer,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Center(
                    child: Text('$level', style: theme.textTheme.titleLarge),
                  ),
                ),
              ),
            );
          }

          final cells = <Widget>[
            for (var row = 0; row < board.rowCount; row++)
              for (var column = 0; column < board.columnCount; column++)
                Positioned(
                  left: column * (cellWidth + _spacing),
                  top: row * (cellHeight + _spacing),
                  width: cellWidth,
                  height: cellHeight,
                  child: DecoratedBox(
                    key: ValueKey(
                      'board_cell_${row * board.columnCount + column}',
                    ),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.surfaceContainerHighest,
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                ),
          ];

          if (previous != null && move != null && progress < _slideEnd) {
            final destinations = {
              for (final movement in move.movements) movement.from: movement.to,
            };
            final slide = Curves.easeOutCubic.transform(
              _fraction(progress, 0, _slideEnd),
            );

            for (var row = 0; row < previous.rowCount; row++) {
              for (var column = 0; column < previous.columnCount; column++) {
                final level = previous.tileAt(
                  rowIndex: row,
                  columnIndex: column,
                );
                if (level == null) continue;

                final source = (rowIndex: row, columnIndex: column);
                final destination = destinations[source] ?? source;
                cells.add(
                  tile(
                    position: source,
                    level: level,
                    identifier: 'moving_tile_${row}_$column',
                    location: Offset.lerp(
                      offset(source),
                      offset(destination),
                      slide,
                    ),
                  ),
                );
              }
            }
          } else {
            final mergedPositions = animating
                ? {for (final merge in move.merges) merge.destination}
                : <BoardPosition>{};
            final spawnPosition = animating ? move.spawnedTile?.position : null;

            for (var row = 0; row < board.rowCount; row++) {
              for (var column = 0; column < board.columnCount; column++) {
                final level = board.tileAt(rowIndex: row, columnIndex: column);
                if (level == null) continue;

                final position = (rowIndex: row, columnIndex: column);
                if (position == spawnPosition && progress < _spawnStart) {
                  continue;
                }

                var scale = 1.0;
                if (position == spawnPosition) {
                  scale = Curves.easeOutBack.transform(
                    _fraction(progress, _spawnStart, 1),
                  );
                } else if (mergedPositions.contains(position)) {
                  scale =
                      0.85 +
                      0.15 *
                          Curves.easeOutBack.transform(
                            _fraction(progress, _slideEnd, _spawnStart),
                          );
                }

                cells.add(
                  tile(
                    position: position,
                    level: level,
                    identifier: 'tile_${row}_$column',
                    scale: scale,
                  ),
                );
              }
            }
          }

          return Stack(clipBehavior: Clip.none, children: cells);
        },
      ),
    );
  }
}
