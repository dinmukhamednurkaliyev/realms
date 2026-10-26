import 'dart:math';

import 'package:engine/src/game_board.dart';
import 'package:engine/src/game_configuration.dart';
import 'package:engine/src/move_direction.dart';

/// A position on the game board.
typedef TilePosition = ({int rowIndex, int columnIndex});

/// A tile moving from one position to another.
final class TileMovement {
  const TileMovement({
    required this.from,
    required this.to,
    required this.level,
  });

  final TilePosition from;
  final TilePosition to;
  final int level;
}

/// Two tiles merging into one higher-level tile.
final class TileMerge {
  const TileMerge({
    required this.first,
    required this.second,
    required this.destination,
    required this.level,
  });

  final TilePosition first;
  final TilePosition second;
  final TilePosition destination;
  final int level;
}

/// A new tile appearing after a successful move.
final class TileSpawn {
  const TileSpawn({required this.position, required this.level});

  final TilePosition position;
  final int level;
}

/// The outcome of a single attempted move.
final class GameMoveResult {
  GameMoveResult._({
    required this.state,
    required this.changed,
    required this.scoreGained,
    required List<TileMovement> movements,
    required List<TileMerge> merges,
    this.spawnedTile,
  }) : movements = List<TileMovement>.unmodifiable(movements),
       merges = List<TileMerge>.unmodifiable(merges),
       mergedLevels = List<int>.unmodifiable(
         merges.map((merge) => merge.level),
       );

  final GameState state;
  final bool changed;
  final int scoreGained;

  final List<TileMovement> movements;
  final List<TileMerge> merges;
  final TileSpawn? spawnedTile;

  /// Levels created by merges during this move.
  final List<int> mergedLevels;
}

typedef _RowMergeResult = ({
  List<int?> row,
  List<TileMovement> movements,
  List<TileMerge> merges,
});

typedef _BoardMoveResult = ({
  GameBoard board,
  List<TileMovement> movements,
  List<TileMerge> merges,
});

typedef _SpawnResult = ({GameBoard board, TileSpawn event});

/// An immutable game snapshot with validated tile levels and dimensions.
///
/// Each spawn draws `nextInt(emptyCellCount)` to select a position,
/// followed by `nextDouble()` to select a tile level.
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
      final spawn = spawner.spawn(board: board, random: random);

      board = spawn.board;
    }

    return GameState(board: board, configuration: configuration);
  }

  final GameBoard board;
  final GameConfiguration configuration;

  /// Total points earned from successful merges.
  final int score;

  /// Performs a move and returns only the resulting state.
  GameState move({required MoveDirection direction, required Random random}) {
    return moveWithResult(direction: direction, random: random).state;
  }

  /// Performs a move and returns the resulting state and events.
  ///
  /// An unchanged move returns the original state without using random.
  GameMoveResult moveWithResult({
    required MoveDirection direction,
    required Random random,
  }) {
    final movement = _BoardMovement(maxTileLevel: configuration.maxTileLevel)
        .move(board: board, direction: direction);

    if (board == movement.board) {
      return GameMoveResult._(
        state: this,
        changed: false,
        scoreGained: 0,
        movements: const [],
        merges: const [],
      );
    }

    final spawner = _TileSpawner(spawnWeights: configuration.spawnWeights);

    final spawn = spawner.spawn(board: movement.board, random: random);

    final gainedScore = movement.merges.fold<int>(
      0,
      (total, merge) => total + _pointsForMerge(mergedLevel: merge.level),
    );

    final nextState = GameState(
      board: spawn.board,
      configuration: configuration,
      score: score + gainedScore,
    );

    return GameMoveResult._(
      state: nextState,
      changed: true,
      scoreGained: gainedScore,
      movements: movement.movements,
      merges: movement.merges,
      spawnedTile: spawn.event,
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
    // Create independent, mutable rows for the next board.
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

      final result = _mergeRow(board: board, positions: positions);

      // Write each resulting value to its real board position.
      for (
        var positionIndex = 0;
        positionIndex < positions.length;
        positionIndex++
      ) {
        final position = positions[positionIndex];

        nextRows[position.rowIndex][position.columnIndex] =
            result.row[positionIndex];
      }

      movements.addAll(result.movements);
      merges.addAll(result.merges);
    }

    return (
      board: GameBoard(rows: nextRows),
      movements: movements,
      merges: merges,
    );
  }

  /// Returns positions ordered from the movement side inward.
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

  /// Merges a line ordered from the movement side inward.
  ///
  /// The normalized line may represent a physical row or column.
  _RowMergeResult _mergeRow({
    required GameBoard board,
    required List<TilePosition> positions,
  }) {
    final tiles = <({int level, TilePosition position})>[];

    // Preserve the original position of every occupied cell.
    for (final position in positions) {
      final level = board.tileAt(
        rowIndex: position.rowIndex,
        columnIndex: position.columnIndex,
      );

      if (level != null) {
        tiles.add((level: level, position: position));
      }
    }

    final mergedRow = <int?>[];
    final movements = <TileMovement>[];
    final merges = <TileMerge>[];

    var index = 0;

    while (index < tiles.length) {
      final current = tiles[index];

      // The output cell corresponds to the next occupied slot.
      final destination = positions[mergedRow.length];

      final hasNextTile = index + 1 < tiles.length;

      final canMerge =
          hasNextTile &&
          current.level == tiles[index + 1].level &&
          current.level < _maxTileLevel;

      if (canMerge) {
        final next = tiles[index + 1];
        final nextLevel = current.level + 1;

        mergedRow.add(nextLevel);

        _addMovement(
          movements: movements,
          from: current.position,
          to: destination,
          level: current.level,
        );

        _addMovement(
          movements: movements,
          from: next.position,
          to: destination,
          level: next.level,
        );

        merges.add(
          TileMerge(
            first: current.position,
            second: next.position,
            destination: destination,
            level: nextLevel,
          ),
        );

        index += 2;
      } else {
        mergedRow.add(current.level);

        _addMovement(
          movements: movements,
          from: current.position,
          to: destination,
          level: current.level,
        );

        index += 1;
      }
    }

    // Fill the remaining cells with null.
    while (mergedRow.length < positions.length) {
      mergedRow.add(null);
    }

    return (row: mergedRow, movements: movements, merges: merges);
  }

  void _addMovement({
    required List<TileMovement> movements,
    required TilePosition from,
    required TilePosition to,
    required int level,
  }) {
    // Stationary tiles do not need movement animations.
    if (from == to) {
      return;
    }

    movements.add(TileMovement(from: from, to: to, level: level));
  }
}

final class _TileSpawner {
  const new({required this._spawnWeights});

  final Map<int, int> _spawnWeights;

  _SpawnResult spawn({required GameBoard board, required Random random}) {
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

    final position = emptyPositions[random.nextInt(emptyPositions.length)];

    final level = _selectLevel(random: random);

    final nextRows = <List<int?>>[];

    for (final row in board.rows) {
      nextRows.add(List<int?>.of(row));
    }

    nextRows[position.rowIndex][position.columnIndex] = level;

    return (
      board: GameBoard(rows: nextRows),
      event: TileSpawn(position: position, level: level),
    );
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
