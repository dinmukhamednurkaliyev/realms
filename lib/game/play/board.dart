import 'package:flutter/material.dart';
import 'package:realms/app/appearance/appearance.dart';
import 'package:realms/app/asset/asset.dart';
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

  /// End of the sliding phase, used to synchronize merge sound effects.
  static const double slideEnd = 0.52;

  /// Start of the new-tile appearance phase.
  static const double spawnStart = 0.76;

  static const int _imageCacheWidth = 512;

  // Asset keys come from the project resource generator.
  // An empty cell has no image, and missing higher levels use numbers.
  static String? _imageForLevel(int? level) => switch (level) {
    1 => assets.game.images.forest.levels.one,
    2 => assets.game.images.forest.levels.two,
    3 => assets.game.images.forest.levels.three,
    4 => assets.game.images.forest.levels.four,
    5 => assets.game.images.forest.levels.five,
    6 => assets.game.images.forest.levels.six,
    _ => null,
  };

  static Widget _artwork(BuildContext context, int? level) {
    final theme = Theme.of(context);
    final appearance = GameAppearance.of(context);
    final image = _imageForLevel(level);
    Widget fallback() => DecoratedBox(
      decoration: BoxDecoration(
        color: level == null ? appearance.emptyCell : appearance.fallbackTile,
        borderRadius: BorderRadius.circular(appearance.cellRadius),
      ),
      child: level == null
          ? null
          : Center(child: Text('$level', style: theme.textTheme.titleLarge)),
    );

    if (image != null) {
      return Image.asset(
        image,
        fit: BoxFit.contain,
        cacheWidth: _imageCacheWidth,
        errorBuilder: (context, error, stackTrace) => fallback(),
      );
    }

    return fallback();
  }

  static double _fraction(double value, double start, double end) {
    if (value <= start) return 0;
    if (value >= end) return 1;
    return (value - start) / (end - start);
  }

  @override
  Widget build(BuildContext context) {
    final spacing = GameAppearance.of(context).cellSpacing;
    final previous = previousBoard;
    final move = lastMove;
    final animating = previous != null && move != null && progress < 1;

    return AspectRatio(
      aspectRatio: board.columnCount / board.rowCount,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final cellWidth =
              (constraints.maxWidth - spacing * (board.columnCount - 1)) /
              board.columnCount;
          final cellHeight =
              (constraints.maxHeight - spacing * (board.rowCount - 1)) /
              board.rowCount;

          Offset offset(BoardPosition position) => Offset(
            position.columnIndex * (cellWidth + spacing),
            position.rowIndex * (cellHeight + spacing),
          );

          Widget tile({
            required BoardPosition position,
            required int level,
            required String identifier,
            double scale = 1,
            double opacity = 1,
            Offset? location,
          }) {
            final target = location ?? offset(position);
            return Positioned(
              left: target.dx,
              top: target.dy,
              width: cellWidth,
              height: cellHeight,
              child: Opacity(
                opacity: opacity,
                child: Transform.scale(
                  scale: scale,
                  child: SizedBox.expand(
                    key: ValueKey(identifier),
                    child: _artwork(context, level),
                  ),
                ),
              ),
            );
          }

          final cells = <Widget>[
            for (var row = 0; row < board.rowCount; row++)
              for (var column = 0; column < board.columnCount; column++)
                Positioned(
                  left: column * (cellWidth + spacing),
                  top: row * (cellHeight + spacing),
                  width: cellWidth,
                  height: cellHeight,
                  child: SizedBox.expand(
                    key: ValueKey(
                      'board_cell_${row * board.columnCount + column}',
                    ),
                    child: _artwork(context, null),
                  ),
                ),
          ];

          if (previous != null && move != null && progress < slideEnd) {
            final destinations = {
              for (final movement in move.movements) movement.from: movement.to,
            };

            final slide = Curves.easeOutCubic.transform(
              _fraction(progress, 0, slideEnd),
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

                if (position == spawnPosition && progress < spawnStart) {
                  continue;
                }

                var scale = 1.0;
                var opacity = 1.0;

                if (position == spawnPosition && animating) {
                  final phase = _fraction(progress, spawnStart, 1);

                  scale = 0.55 + 0.45 * Curves.easeOutBack.transform(phase);
                  opacity = Curves.easeOut.transform(phase);
                } else if (mergedPositions.contains(position)) {
                  final phase = _fraction(progress, slideEnd, spawnStart);

                  // A single controlled impact: grow and settle back to 1.
                  scale = 1 + 0.16 * (4 * phase * (1 - phase));
                }

                cells.add(
                  tile(
                    position: position,
                    level: level,
                    identifier: 'tile_${row}_$column',
                    scale: scale,
                    opacity: opacity,
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
