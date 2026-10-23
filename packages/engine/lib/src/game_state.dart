import 'dart:math';

import 'package:engine/src/game_board.dart';
import 'package:engine/src/game_configuration.dart';
import 'package:engine/src/move_direction.dart';

/// An immutable game snapshot with validated tile levels and dimensions.
///
/// Each spawn draws `nextInt(emptyCellCount)` to index empty cells enumerated
/// in row-major order, then `nextDouble()` to select a level using
/// [GameConfiguration.spawnWeights].
final class GameState {
  new({required this.board, GameConfiguration? configuration})
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

  /// Creates a board with [GameConfiguration.initialTileCount] spawned tiles.
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

  /// Slides and merges tiles, then spawns one tile only if the board changed.
  ///
  /// Returns this state without drawing from [random] when nothing moves.
  /// Changed moves return a new state with the same configuration instance.
  /// The caller owns [random]; reuse it across turns to advance its sequence.
  GameState move({required MoveDirection direction, required Random random}) {
    final movement = _BoardMovement(maxTileLevel: configuration.maxTileLevel);
    final movedBoard = movement.move(board: board, direction: direction);

    if (board == movedBoard) {
      return this;
    }

    final spawner = _TileSpawner(spawnWeights: configuration.spawnWeights);
    final nextBoard = spawner.spawn(board: movedBoard, random: random);

    return GameState(board: nextBoard, configuration: configuration);
  }
}

final class _BoardMovement {
  const new({required this._maxTileLevel});

  final int _maxTileLevel;

  GameBoard move({required GameBoard board, required MoveDirection direction}) {
    return GameBoard(
      rows: switch (direction) {
        MoveDirection.left => _moveLeft(rows: board.rows),
        MoveDirection.right => _moveRight(rows: board.rows),
        MoveDirection.up => _moveUp(rows: board.rows),
        MoveDirection.down => _moveDown(rows: board.rows),
      },
    );
  }

  List<int?> _mergeLine({required List<int?> line}) {
    final tiles = line.whereType<int>().toList();
    final result = <int?>[];
    var index = 0;

    while (index < tiles.length) {
      final current = tiles[index];

      if (index + 1 < tiles.length &&
          current == tiles[index + 1] &&
          current < _maxTileLevel) {
        result.add(current + 1);
        index += 2;
      } else {
        result.add(current);
        index += 1;
      }
    }

    while (result.length < line.length) {
      result.add(null);
    }

    return result;
  }

  List<List<int?>> _moveLeft({required List<List<int?>> rows}) {
    return [for (final row in rows) _mergeLine(line: row)];
  }

  List<List<int?>> _moveRight({required List<List<int?>> rows}) {
    final movedRows = <List<int?>>[];

    for (final row in rows) {
      final reversedRow = row.reversed.toList();
      final mergedRow = _mergeLine(line: reversedRow);

      movedRows.add(mergedRow.reversed.toList());
    }

    return movedRows;
  }

  List<List<int?>> _moveUp({required List<List<int?>> rows}) {
    final columns = _transpose(rows: rows);
    final movedColumns = _moveLeft(rows: columns);

    return _transpose(rows: movedColumns);
  }

  List<List<int?>> _moveDown({required List<List<int?>> rows}) {
    final columns = _transpose(rows: rows);
    final movedColumns = _moveRight(rows: columns);

    return _transpose(rows: movedColumns);
  }

  List<List<int?>> _transpose({required List<List<int?>> rows}) {
    return [
      for (var columnIndex = 0; columnIndex < rows.first.length; columnIndex++)
        [for (final row in rows) row[columnIndex]],
    ];
  }
}

final class _TileSpawner {
  const new({required this._spawnWeights});

  final Map<int, int> _spawnWeights;

  GameBoard spawn({required GameBoard board, required Random random}) {
    final emptyPositions = [
      for (var rowIndex = 0; rowIndex < board.rowCount; rowIndex++)
        for (
          var columnIndex = 0;
          columnIndex < board.columnCount;
          columnIndex++
        )
          if (board.tileAt(rowIndex: rowIndex, columnIndex: columnIndex) ==
              null)
            (rowIndex: rowIndex, columnIndex: columnIndex),
    ];

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
