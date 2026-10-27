import 'dart:math';

import 'package:engine/src/game_board.dart';
import 'package:engine/src/game_events.dart';

/// The resulting board and location of one newly spawned tile.
typedef TileSpawnResult = ({GameBoard board, TileSpawn event});

/// Places a new tile according to the configured relative spawn weights.
///
/// This is package-internal. Callers must provide validated, immutable
/// weights, normally obtained from `GameConfiguration.spawnWeights`.
final class TileSpawner {
  /// Uses [_spawnWeights] when selecting the level of every spawned tile.
  const new({required this._spawnWeights});

  final Map<int, int> _spawnWeights;

  /// Spawns one tile into a randomly selected empty position.
  ///
  /// Empty cells are enumerated in row-major order. Exactly one `nextInt`
  /// selects the position and one `nextDouble` selects the level, in that
  /// order. Throws [StateError] if the board contains no empty position.
  TileSpawnResult spawn({required GameBoard board, required Random random}) {
    final emptyPositions = <TilePosition>[];

    for (var rowIndex = 0; rowIndex < board.rowCount; rowIndex++) {
      for (
        var columnIndex = 0;
        columnIndex < board.columnCount;
        columnIndex++
      ) {
        if (board.tileAt(rowIndex: rowIndex, columnIndex: columnIndex) ==
            null) {
          emptyPositions.add((rowIndex: rowIndex, columnIndex: columnIndex));
        }
      }
    }

    if (emptyPositions.isEmpty) {
      throw StateError('Cannot spawn a tile on a full board.');
    }

    final selectedPosition =
        emptyPositions[random.nextInt(emptyPositions.length)];
    final spawnedLevel = _selectLevel(random: random);

    final nextRows = <List<int?>>[];

    for (final row in board.rows) {
      nextRows.add(List<int?>.of(row));
    }

    nextRows[selectedPosition.rowIndex][selectedPosition.columnIndex] =
        spawnedLevel;

    return (
      board: GameBoard(rows: nextRows),
      event: TileSpawn(position: selectedPosition, level: spawnedLevel),
    );
  }

  int _selectLevel({required Random random}) {
    final totalWeight = _spawnWeights.values.fold<int>(
      0,
      (total, weight) => total + weight,
    );

    final roll = random.nextDouble() * totalWeight;
    var cumulativeWeight = 0;

    for (final entry in _spawnWeights.entries) {
      cumulativeWeight += entry.value;

      if (roll < cumulativeWeight) {
        return entry.key;
      }
    }

    throw StateError('Cannot select a spawn value.');
  }
}
