import 'dart:math';

import 'package:engine/src/game_board.dart';
import 'package:engine/src/game_configuration.dart';
import 'package:engine/src/move_direction.dart';

typedef _RowMergeResult = ({List<int?> row, List<int> mergedLevels});

typedef _RowsMoveResult = ({List<List<int?>> rows, List<int> mergedLevels});

typedef _BoardMoveResult = ({GameBoard board, List<int> mergedLevels});

/// An immutable game snapshot with validated tile levels and dimensions.
///
/// Each spawn draws `nextInt(emptyCellCount)` to index empty cells enumerated
/// in row-major order, then `nextDouble()` to select a level using
/// [GameConfiguration.spawnWeights].
final class GameState {
  new({required this.board, this.score = 0, GameConfiguration? configuration})
    : configuration =
          configuration ??
          GameConfiguration(
            rowCount: board.rowCount,
            columnCount: board.columnCount,
            initialTileCount: min(2, board.rowCount * board.columnCount),
          ) {
    if (this.configuration.rowCount != board.rowCount ||
        this.configuration.columnCount != board.columnCount) {
      throw ArgumentError(
        'Game configuration dimensions must match the board.',
      );
    }

    if (score < 0) {
      throw ArgumentError.value(score, 'score', 'Must not be negative.');
    }

    for (final row in board.rows) {
      for (final level in row) {
        if (level != null &&
            (level < 1 || level > this.configuration.maxTileLevel)) {
          throw ArgumentError.value(
            level,
            'board',
            'Tile level is outside the configured evolution range.',
          );
        }
      }
    }
  }

  /// Creates a board with the configured number of starting tiles.
  factory start({
    required GameConfiguration configuration,
    required Random random,
  }) {
    var board = GameBoard.empty(
      rowCount: configuration.rowCount,
      columnCount: configuration.columnCount,
    );

    final spawner = _TileSpawner(spawnWeights: configuration.spawnWeights);

    for (var index = 0; index < configuration.initialTileCount; index++) {
      board = spawner.spawn(board: board, random: random);
    }

    return GameState(board: board, configuration: configuration);
  }

  final GameBoard board;
  final GameConfiguration configuration;

  /// Total points earned from successful tile merges.
  final int score;

  /// Moves and merges tiles, then spawns one tile if the board changed.
  ///
  /// An unchanged move returns this state without consuming random values.
  GameState move({required MoveDirection direction, required Random random}) {
    final movement = _BoardMovement(maxTileLevel: configuration.maxTileLevel)
        .move(board: board, direction: direction);

    if (board == movement.board) {
      return this;
    }

    final spawner = _TileSpawner(spawnWeights: configuration.spawnWeights);

    final nextBoard = spawner.spawn(board: movement.board, random: random);

    final gainedScore = movement.mergedLevels.fold<int>(
      0,
      (total, mergedLevel) => total + _pointsForMerge(mergedLevel: mergedLevel),
    );

    return GameState(
      board: nextBoard,
      configuration: configuration,
      score: score + gainedScore,
    );
  }

  int _pointsForMerge({required int mergedLevel}) {
    return configuration.mergeScoreMultiplier * mergedLevel * mergedLevel;
  }
}

final class _BoardMovement {
  const new({required this._maxTileLevel});

  final int _maxTileLevel;

  _BoardMoveResult move({
    required GameBoard board,
    required MoveDirection direction,
  }) {
    final result = switch (direction) {
      MoveDirection.left => _moveLeft(rows: board.rows),
      MoveDirection.right => _moveRight(rows: board.rows),
      MoveDirection.up => _moveUp(rows: board.rows),
      MoveDirection.down => _moveDown(rows: board.rows),
    };

    return (
      board: GameBoard(rows: result.rows),
      mergedLevels: result.mergedLevels,
    );
  }

  _RowMergeResult _mergeRow({required List<int?> row}) {
    final tiles = row.whereType<int>().toList();
    final mergedRow = <int?>[];
    final mergedLevels = <int>[];

    var index = 0;

    while (index < tiles.length) {
      final current = tiles[index];

      if (index + 1 < tiles.length &&
          current == tiles[index + 1] &&
          current < _maxTileLevel) {
        final nextLevel = current + 1;

        mergedRow.add(nextLevel);
        mergedLevels.add(nextLevel);

        index += 2;
      } else {
        mergedRow.add(current);
        index += 1;
      }
    }

    while (mergedRow.length < row.length) {
      mergedRow.add(null);
    }

    return (row: mergedRow, mergedLevels: mergedLevels);
  }

  _RowsMoveResult _moveLeft({required List<List<int?>> rows}) {
    final movedRows = <List<int?>>[];
    final mergedLevels = <int>[];

    for (final row in rows) {
      final result = _mergeRow(row: row);

      movedRows.add(result.row);
      mergedLevels.addAll(result.mergedLevels);
    }

    return (rows: movedRows, mergedLevels: mergedLevels);
  }

  _RowsMoveResult _moveRight({required List<List<int?>> rows}) {
    final movedRows = <List<int?>>[];
    final mergedLevels = <int>[];

    for (final row in rows) {
      final reversedRow = row.reversed.toList();
      final result = _mergeRow(row: reversedRow);

      movedRows.add(result.row.reversed.toList());
      mergedLevels.addAll(result.mergedLevels);
    }

    return (rows: movedRows, mergedLevels: mergedLevels);
  }

  _RowsMoveResult _moveUp({required List<List<int?>> rows}) {
    final columns = _transpose(rows: rows);
    final result = _moveLeft(rows: columns);

    return (
      rows: _transpose(rows: result.rows),
      mergedLevels: result.mergedLevels,
    );
  }

  _RowsMoveResult _moveDown({required List<List<int?>> rows}) {
    final columns = _transpose(rows: rows);
    final result = _moveRight(rows: columns);

    return (
      rows: _transpose(rows: result.rows),
      mergedLevels: result.mergedLevels,
    );
  }

  List<List<int?>> _transpose({required List<List<int?>> rows}) {
    final rowCount = rows.length;
    final columnCount = rows.first.length;
    final transposedRows = <List<int?>>[];

    for (var columnIndex = 0; columnIndex < columnCount; columnIndex++) {
      final transposedRow = <int?>[];

      for (var rowIndex = 0; rowIndex < rowCount; rowIndex++) {
        transposedRow.add(rows[rowIndex][columnIndex]);
      }

      transposedRows.add(transposedRow);
    }

    return transposedRows;
  }
}

final class _TileSpawner {
  const new({required this._spawnWeights});

  final Map<int, int> _spawnWeights;

  GameBoard spawn({required GameBoard board, required Random random}) {
    final emptyPositions = <({int rowIndex, int columnIndex})>[];

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

    final position = emptyPositions[random.nextInt(emptyPositions.length)];

    final level = _selectLevel(random: random);

    final nextRows = <List<int?>>[
      for (final row in board.rows) [...row],
    ];

    nextRows[position.rowIndex][position.columnIndex] = level;

    return GameBoard(rows: nextRows);
  }

  int _selectLevel({required Random random}) {
    final totalWeight = _spawnWeights.values.fold(
      0,
      (sum, weight) => sum + weight,
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
