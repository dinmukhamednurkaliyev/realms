import 'dart:math';

import 'board.dart';
import 'events.dart';

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

typedef _LineMovementResult = ({
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
bool hasAvailableMoves({required Board board, required int maxTileLevel}) {
  for (var rowIndex = 0; rowIndex < board.rowCount; rowIndex++) {
    for (var columnIndex = 0; columnIndex < board.columnCount; columnIndex++) {
      final tileLevel = board.tileAt(
        rowIndex: rowIndex,
        columnIndex: columnIndex,
      );

      if (columnIndex + 1 < board.columnCount &&
          _canSlideOrMerge(
            tileLevel,
            board.tileAt(rowIndex: rowIndex, columnIndex: columnIndex + 1),
            maxTileLevel,
          )) {
        return true;
      }

      if (rowIndex + 1 < board.rowCount &&
          _canSlideOrMerge(
            tileLevel,
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
  if (firstLevel == null) {
    return secondLevel != null;
  }

  if (secondLevel == null) {
    return true;
  }

  return _canMergeTiles(firstLevel, secondLevel, maxTileLevel);
}

bool _canMergeTiles(int firstLevel, int secondLevel, int maxTileLevel) =>
    firstLevel == secondLevel && firstLevel < maxTileLevel;

/// Slides and merges tiles in [direction], returning the board and events.
///
/// Tiles with the same level merge once per move, unless they have already
/// reached the maximum configured level. Movement events omit stationary
/// tiles, while merge events record both sources even if one is stationary.
/// The returned board and event lists are immutable.
///
/// Internal callers supply tile levels and a merge limit validated by
/// `State`. This operation does not spawn tiles or calculate scores.
({Board board, List<TileMovement> movements, List<TileMerge> merges})
moveBoard({
  required Board board,
  required MoveDirection direction,
  required int maxTileLevel,
}) {
  final movedRows = [
    for (final row in board.rows) [...row],
  ];

  final movements = <TileMovement>[];
  final merges = <TileMerge>[];

  final isHorizontal =
      direction == MoveDirection.left || direction == MoveDirection.right;
  final lineCount = isHorizontal ? board.rowCount : board.columnCount;

  for (var lineIndex = 0; lineIndex < lineCount; lineIndex++) {
    final linePositions = _positionsForLine(
      board: board,
      direction: direction,
      lineIndex: lineIndex,
    );

    final lineMovement = _slideAndMergeLine(
      board: board,
      linePositions: linePositions,
      maxTileLevel: maxTileLevel,
    );

    // Map the destination-first line back onto board coordinates.
    for (
      var positionIndex = 0;
      positionIndex < linePositions.length;
      positionIndex++
    ) {
      final destinationPosition = linePositions[positionIndex];

      movedRows[destinationPosition.rowIndex][destinationPosition.columnIndex] =
          lineMovement.cells[positionIndex];
    }

    movements.addAll(lineMovement.movements);
    merges.addAll(lineMovement.merges);
  }

  return (
    board: Board(rows: movedRows),
    movements: List<TileMovement>.unmodifiable(movements),
    merges: List<TileMerge>.unmodifiable(merges),
  );
}

/// Orders a physical row or column from the destination edge inward.
List<BoardPosition> _positionsForLine({
  required Board board,
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
/// [linePositions] runs from the destination edge toward the far edge.
_LineMovementResult _slideAndMergeLine({
  required Board board,
  required List<BoardPosition> linePositions,
  required int maxTileLevel,
}) {
  final sourceTiles = <({int level, BoardPosition position})>[];

  for (final sourcePosition in linePositions) {
    final tileLevel = board.tileAt(
      rowIndex: sourcePosition.rowIndex,
      columnIndex: sourcePosition.columnIndex,
    );

    if (tileLevel != null) {
      sourceTiles.add((level: tileLevel, position: sourcePosition));
    }
  }

  final destinationCells = <int?>[];
  final movements = <TileMovement>[];
  final merges = <TileMerge>[];
  var sourceIndex = 0;

  while (sourceIndex < sourceTiles.length) {
    final sourceTile = sourceTiles[sourceIndex];
    final followingTile = sourceIndex + 1 < sourceTiles.length
        ? sourceTiles[sourceIndex + 1]
        : null;
    final destinationPosition = linePositions[destinationCells.length];

    _recordMovementIfChanged(
      movements: movements,
      from: sourceTile.position,
      to: destinationPosition,
      level: sourceTile.level,
    );

    if (followingTile == null ||
        !_canMergeTiles(sourceTile.level, followingTile.level, maxTileLevel)) {
      destinationCells.add(sourceTile.level);
      sourceIndex++;
      continue;
    }

    final mergedLevel = sourceTile.level + 1;
    destinationCells.add(mergedLevel);

    _recordMovementIfChanged(
      movements: movements,
      from: followingTile.position,
      to: destinationPosition,
      level: followingTile.level,
    );

    merges.add(
      TileMerge(
        firstSource: sourceTile.position,
        secondSource: followingTile.position,
        destination: destinationPosition,
        level: mergedLevel,
      ),
    );

    // Only original tiles are consumed, so a new tile cannot merge again.
    sourceIndex += 2;
  }

  while (destinationCells.length < linePositions.length) {
    destinationCells.add(null);
  }

  return (cells: destinationCells, movements: movements, merges: merges);
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
/// Internal callers supply spawn weights validated by `Configuration`.
({Board board, TileSpawn spawnedTile}) spawnTile({
  required Board board,
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

  final spawnPosition = emptyPositions[random.nextInt(emptyPositions.length)];
  final spawnLevel = _selectSpawnLevel(
    random: random,
    spawnWeights: spawnWeights,
  );

  final rowsWithSpawn = [
    for (final row in board.rows) [...row],
  ];

  rowsWithSpawn[spawnPosition.rowIndex][spawnPosition.columnIndex] = spawnLevel;

  return (
    board: Board(rows: rowsWithSpawn),
    spawnedTile: TileSpawn(position: spawnPosition, level: spawnLevel),
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

  final weightedDraw = random.nextDouble() * totalWeight;
  var cumulativeWeight = 0;

  for (final MapEntry(key: tileLevel, value: weight) in spawnWeights.entries) {
    cumulativeWeight += weight;

    if (weightedDraw < cumulativeWeight) {
      return tileLevel;
    }
  }

  throw StateError('Cannot select a spawn value.');
}
