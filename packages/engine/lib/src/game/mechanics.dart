import 'dart:math';

import 'package:engine/src/game/board.dart';
import 'package:engine/src/game/events.dart';

/// A direction in which the player slides all tiles on the board.
enum MoveDirection {
  /// Slides tiles toward the top edge.
  up,

  /// Slides tiles toward the bottom edge.
  down,

  /// Slides tiles toward the left edge.
  left,

  /// Slides tiles toward the right edge.
  right,
}

typedef _LineMoveResult = ({
  List<int?> cells,
  List<TileMovement> movements,
  List<TileMerge> merges,
});

/// Whether any direction can change a validated board before spawning.
///
/// An occupied cell beside an empty cell allows a slide. Otherwise, a move
/// requires adjacent tiles that can merge. Checking right and down covers
/// every neighboring pair once, including single rows and columns.
/// No boards or events are constructed, and no randomness is consumed.
bool canMoveBoard({required GameBoard board, required int maxTileLevel}) {
  for (var rowIndex = 0; rowIndex < board.rowCount; rowIndex++) {
    for (var columnIndex = 0; columnIndex < board.columnCount; columnIndex++) {
      final level = board.tileAt(rowIndex: rowIndex, columnIndex: columnIndex);

      if (columnIndex + 1 < board.columnCount &&
          _canSlideOrMerge(
            level,
            board.tileAt(rowIndex: rowIndex, columnIndex: columnIndex + 1),
            maxTileLevel,
          )) {
        return true;
      }

      if (rowIndex + 1 < board.rowCount &&
          _canSlideOrMerge(
            level,
            board.tileAt(rowIndex: rowIndex + 1, columnIndex: columnIndex),
            maxTileLevel,
          )) {
        return true;
      }
    }
  }

  return false;
}

bool _canSlideOrMerge(int? firstLevel, int? secondLevel, int maxTileLevel) {
  if (firstLevel == null || secondLevel == null) {
    return firstLevel != secondLevel;
  }

  return _canMergeTiles(firstLevel, secondLevel, maxTileLevel);
}

bool _canMergeTiles(int firstLevel, int secondLevel, int maxTileLevel) =>
    firstLevel == secondLevel && firstLevel < maxTileLevel;

/// Slides a board in [direction] and describes any resulting merges.
///
/// Tiles with the same level merge once per move, unless they have already
/// reached the maximum configured level. Movement events omit stationary
/// tiles, while merge events record both sources even if one is stationary.
/// The returned board and event lists are immutable.
///
/// Internal callers supply tile levels and a merge limit validated by
/// `GameState`. This operation does not spawn tiles or calculate scores.
({GameBoard board, List<TileMovement> movements, List<TileMerge> merges})
moveBoard({
  required GameBoard board,
  required MoveDirection direction,
  required int maxTileLevel,
}) {
  // Changes are assembled in mutable copies. The original board remains
  // untouched even when individual source tiles do not move.
  final nextRows = [
    for (final row in board.rows) [...row],
  ];

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

    final lineMove = _slideAndMergeLine(
      board: board,
      positions: positions,
      maxTileLevel: maxTileLevel,
    );

    // The ordered positions map the normalized line back onto real cells.
    for (
      var positionIndex = 0;
      positionIndex < positions.length;
      positionIndex++
    ) {
      final destinationPosition = positions[positionIndex];

      nextRows[destinationPosition.rowIndex][destinationPosition.columnIndex] =
          lineMove.cells[positionIndex];
    }

    movements.addAll(lineMove.movements);
    merges.addAll(lineMove.merges);
  }

  return (
    board: GameBoard(rows: nextRows),
    movements: List<TileMovement>.unmodifiable(movements),
    merges: List<TileMerge>.unmodifiable(merges),
  );
}

/// Orders a physical row or column from the destination edge inward.
List<BoardPosition> _positionsForLine({
  required GameBoard board,
  required MoveDirection direction,
  required int lineIndex,
}) {
  final lineLength = switch (direction) {
    MoveDirection.left || MoveDirection.right => board.columnCount,
    MoveDirection.up || MoveDirection.down => board.rowCount,
  };

  return List.generate(
    lineLength,
    (positionIndex) => switch (direction) {
      MoveDirection.left => (rowIndex: lineIndex, columnIndex: positionIndex),
      MoveDirection.right => (
        rowIndex: lineIndex,
        columnIndex: lineLength - 1 - positionIndex,
      ),
      MoveDirection.up => (rowIndex: positionIndex, columnIndex: lineIndex),
      MoveDirection.down => (
        rowIndex: lineLength - 1 - positionIndex,
        columnIndex: lineIndex,
      ),
    },
  );
}

/// Slides and merges a row or column, preserving original tile positions.
///
/// [positions] always points from the destination edge toward the far edge.
_LineMoveResult _slideAndMergeLine({
  required GameBoard board,
  required List<BoardPosition> positions,
  required int maxTileLevel,
}) {
  final sourceTiles = <({int level, BoardPosition position})>[];

  for (final sourcePosition in positions) {
    final level = board.tileAt(
      rowIndex: sourcePosition.rowIndex,
      columnIndex: sourcePosition.columnIndex,
    );

    if (level != null) {
      sourceTiles.add((level: level, position: sourcePosition));
    }
  }

  final movedCells = <int?>[];
  final movements = <TileMovement>[];
  final merges = <TileMerge>[];
  var sourceIndex = 0;

  while (sourceIndex < sourceTiles.length) {
    final currentTile = sourceTiles[sourceIndex];
    final destinationPosition = positions[movedCells.length];
    final hasNextTile = sourceIndex + 1 < sourceTiles.length;
    final canMerge =
        hasNextTile &&
        _canMergeTiles(
          currentTile.level,
          sourceTiles[sourceIndex + 1].level,
          maxTileLevel,
        );

    _recordMovementIfChanged(
      movements: movements,
      from: currentTile.position,
      to: destinationPosition,
      level: currentTile.level,
    );

    if (canMerge) {
      final nextTile = sourceTiles[sourceIndex + 1];
      final mergedLevel = currentTile.level + 1;
      movedCells.add(mergedLevel);

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
      movedCells.add(currentTile.level);
      sourceIndex++;
    }
  }

  while (movedCells.length < positions.length) {
    movedCells.add(null);
  }

  return (cells: movedCells, movements: movements, merges: merges);
}

void _recordMovementIfChanged({
  required List<TileMovement> movements,
  required BoardPosition from,
  required BoardPosition to,
  required int level,
}) {
  if (from == to) {
    return;
  }

  movements.add(TileMovement(from: from, to: to, level: level));
}

/// Spawns one tile into a randomly selected empty position.
///
/// Empty cells are enumerated in row-major order. Exactly one `nextInt`
/// selects the position and one `nextDouble` selects the level, in that
/// order. Throws [StateError] if the board contains no empty position.
/// Internal callers supply spawn weights validated by `GameConfiguration`.
({GameBoard board, TileSpawn event}) spawnTile({
  required GameBoard board,
  required Random random,
  required Map<int, int> spawnWeights,
}) {
  final emptyPositions = <BoardPosition>[];

  for (var rowIndex = 0; rowIndex < board.rowCount; rowIndex++) {
    for (var columnIndex = 0; columnIndex < board.columnCount; columnIndex++) {
      if (board.tileAt(rowIndex: rowIndex, columnIndex: columnIndex) == null) {
        emptyPositions.add((rowIndex: rowIndex, columnIndex: columnIndex));
      }
    }
  }

  if (emptyPositions.isEmpty) {
    throw StateError('Cannot spawn a tile on a full board.');
  }

  final selectedPosition =
      emptyPositions[random.nextInt(emptyPositions.length)];
  final spawnedLevel = _selectSpawnLevel(
    random: random,
    spawnWeights: spawnWeights,
  );

  final nextRows = [
    for (final row in board.rows) [...row],
  ];

  nextRows[selectedPosition.rowIndex][selectedPosition.columnIndex] =
      spawnedLevel;

  return (
    board: GameBoard(rows: nextRows),
    event: TileSpawn(position: selectedPosition, level: spawnedLevel),
  );
}

int _selectSpawnLevel({
  required Random random,
  required Map<int, int> spawnWeights,
}) {
  final totalWeight = spawnWeights.values.fold<int>(
    0,
    (total, weight) => total + weight,
  );

  final roll = random.nextDouble() * totalWeight;
  var cumulativeWeight = 0;

  for (final entry in spawnWeights.entries) {
    cumulativeWeight += entry.value;

    if (roll < cumulativeWeight) {
      return entry.key;
    }
  }

  throw StateError('Cannot select a spawn value.');
}
