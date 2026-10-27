import 'package:engine/src/game_board.dart';
import 'package:engine/src/game_events.dart';
import 'package:engine/src/move_direction.dart';

/// A moved board and the events produced before spawning another tile.
///
/// The movement and merge lists follow destination-edge line order.
typedef BoardMovementResult = ({
  GameBoard board,
  List<TileMovement> movements,
  List<TileMerge> merges,
});

typedef _RowMergeResult = ({
  List<int?> row,
  List<TileMovement> movements,
  List<TileMerge> merges,
});

/// Applies the existing Realms movement and merge rules to a board.
///
/// This implementation is package-internal and independent of spawning,
/// scoring, and Flutter. Its input board is never modified.
final class BoardMovement {
  /// Creates movement rules with the highest mergeable result level.
  const new({required this._maxTileLevel});

  final int _maxTileLevel;

  /// Slides a board in [direction] and describes any resulting merges.
  ///
  /// Tiles with the same level merge once per move, unless they have already
  /// reached the maximum configured level. Movement events omit stationary
  /// tiles, while merge events record both sources even if one is stationary.
  BoardMovementResult move({
    required GameBoard board,
    required MoveDirection direction,
  }) {
    // Changes are assembled in mutable copies. The original board remains
    // untouched even when individual source tiles do not move.
    final nextRows = <List<int?>>[];

    for (final row in board.rows) {
      nextRows.add(List<int?>.of(row));
    }

    final movements = <TileMovement>[];
    final merges = <TileMerge>[];

    final isHorizontal =
        direction == MoveDirection.left || direction == MoveDirection.right;
    final lineCount = isHorizontal ? board.rowCount : board.columnCount;

    for (var lineIndex = 0; lineIndex < lineCount; lineIndex++) {
      final positions = _positionsForLine(
        board: board,
        direction: direction,
        lineIndex: lineIndex,
      );

      final mergedLine = _mergeRow(board: board, positions: positions);

      // The ordered positions map the normalized row back onto real cells.
      for (
        var positionIndex = 0;
        positionIndex < positions.length;
        positionIndex++
      ) {
        final destinationPosition = positions[positionIndex];

        nextRows[destinationPosition.rowIndex][destinationPosition
                .columnIndex] =
            mergedLine.row[positionIndex];
      }

      movements.addAll(mergedLine.movements);
      merges.addAll(mergedLine.merges);
    }

    return (
      board: GameBoard(rows: nextRows),
      movements: movements,
      merges: merges,
    );
  }

  /// Orders a physical row or column from the destination edge inward.
  List<TilePosition> _positionsForLine({
    required GameBoard board,
    required MoveDirection direction,
    required int lineIndex,
  }) {
    final positions = <TilePosition>[];

    switch (direction) {
      case MoveDirection.left:
        for (
          var columnIndex = 0;
          columnIndex < board.columnCount;
          columnIndex++
        ) {
          positions.add((rowIndex: lineIndex, columnIndex: columnIndex));
        }

      case MoveDirection.right:
        for (
          var columnIndex = board.columnCount - 1;
          columnIndex >= 0;
          columnIndex--
        ) {
          positions.add((rowIndex: lineIndex, columnIndex: columnIndex));
        }

      case MoveDirection.up:
        for (var rowIndex = 0; rowIndex < board.rowCount; rowIndex++) {
          positions.add((rowIndex: rowIndex, columnIndex: lineIndex));
        }

      case MoveDirection.down:
        for (var rowIndex = board.rowCount - 1; rowIndex >= 0; rowIndex--) {
          positions.add((rowIndex: rowIndex, columnIndex: lineIndex));
        }
    }

    return positions;
  }

  /// Merges a normalized row, preserving every original tile position.
  ///
  /// For vertical moves the normalized row represents a physical column.
  /// [positions] always points from the destination edge toward the far edge.
  _RowMergeResult _mergeRow({
    required GameBoard board,
    required List<TilePosition> positions,
  }) {
    final sourceTiles = <({int level, TilePosition position})>[];

    for (final sourcePosition in positions) {
      final level = board.tileAt(
        rowIndex: sourcePosition.rowIndex,
        columnIndex: sourcePosition.columnIndex,
      );

      if (level != null) {
        sourceTiles.add((level: level, position: sourcePosition));
      }
    }

    final mergedRow = <int?>[];
    final movements = <TileMovement>[];
    final merges = <TileMerge>[];
    var sourceIndex = 0;

    while (sourceIndex < sourceTiles.length) {
      final currentTile = sourceTiles[sourceIndex];
      final destinationPosition = positions[mergedRow.length];
      final hasNextTile = sourceIndex + 1 < sourceTiles.length;
      final canMerge =
          hasNextTile &&
          currentTile.level == sourceTiles[sourceIndex + 1].level &&
          currentTile.level < _maxTileLevel;

      _recordMovementIfChanged(
        movements: movements,
        from: currentTile.position,
        to: destinationPosition,
        level: currentTile.level,
      );

      if (canMerge) {
        final nextTile = sourceTiles[sourceIndex + 1];
        final mergedLevel = currentTile.level + 1;
        mergedRow.add(mergedLevel);

        _recordMovementIfChanged(
          movements: movements,
          from: nextTile.position,
          to: destinationPosition,
          level: nextTile.level,
        );

        merges.add(
          TileMerge(
            first: currentTile.position,
            second: nextTile.position,
            destination: destinationPosition,
            level: mergedLevel,
          ),
        );

        // Consuming both inputs prevents a freshly merged tile from merging
        // a second time during the same turn.
        sourceIndex += 2;
      } else {
        mergedRow.add(currentTile.level);
        sourceIndex++;
      }
    }

    while (mergedRow.length < positions.length) {
      mergedRow.add(null);
    }

    return (row: mergedRow, movements: movements, merges: merges);
  }

  void _recordMovementIfChanged({
    required List<TileMovement> movements,
    required TilePosition from,
    required TilePosition to,
    required int level,
  }) {
    if (from == to) {
      return;
    }

    movements.add(TileMovement(from: from, to: to, level: level));
  }
}
