import 'dart:math';

import 'package:engine/src/board_movement.dart';
import 'package:engine/src/game_board.dart';
import 'package:engine/src/game_configuration.dart';
import 'package:engine/src/game_events.dart';
import 'package:engine/src/move_direction.dart';
import 'package:engine/src/tile_spawner.dart';

/// The immutable outcome of one attempted movement direction.
///
/// [state] is the resulting snapshot. A failed move retains the original
/// state, earns no points, emits no events, and consumes no random values.
/// A successful move currently spawns exactly one new tile.
final class GameMoveResult {
  new _({
    required this.state,
    required this.changed,
    required this.scoreGained,
    required List<TileMovement> movements,
    required List<TileMerge> merges,
    this.spawnedTile,
  }) : assert(
         changed == (spawnedTile != null),
         'A changed move must spawn a tile, and an unchanged move must not.',
       ),
       movements = List<TileMovement>.unmodifiable(movements),
       merges = List<TileMerge>.unmodifiable(merges),
       mergedLevels = List<int>.unmodifiable(
         merges.map((merge) => merge.level),
       );

  /// The next immutable state, or the original state for an unchanged move.
  final GameState state;

  /// Whether the attempted move changed the board.
  final bool changed;

  /// Points awarded by all merges during this move, excluding prior points.
  final int scoreGained;

  /// Non-stationary tile movements, ordered by processed board line.
  final List<TileMovement> movements;

  /// Merge events, including the original position of stationary sources.
  final List<TileMerge> merges;

  /// The tile spawned after this move, or `null` when nothing changed.
  final TileSpawn? spawnedTile;

  /// Levels produced by this move's merges, in [merges] order.
  ///
  /// This is a convenience projection of [merges], not a second source of
  /// merge data.
  final List<int> mergedLevels;
}

/// An immutable snapshot of a Realms game at one point in time.
///
/// Every successful move produces a new snapshot. The board, rules, and
/// accumulated score in a previous snapshot never change.
final class GameState {
  /// Creates a snapshot from an existing board, optionally restoring a score.
  ///
  /// This does not spawn tiles. When [configuration] is omitted, default
  /// game rules are inferred using the board's dimensions. Always supply the
  /// original configuration when restoring a game with customized rules.
  /// Throws [ArgumentError] for mismatched board dimensions, invalid tile
  /// levels, or a negative [score].
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

  /// Starts a game at zero score with the configured initial tile count.
  ///
  /// The caller owns [random] and should keep using the same random source
  /// for subsequent moves to preserve a reproducible sequence of draws.
  factory start({
    required GameConfiguration configuration,
    required Random random,
  }) {
    var board = GameBoard.empty(
      rowCount: configuration.rowCount,
      columnCount: configuration.columnCount,
    );

    final spawner = TileSpawner(spawnWeights: configuration.spawnWeights);

    for (
      var tileIndex = 0;
      tileIndex < configuration.initialTileCount;
      tileIndex++
    ) {
      final spawnedTile = spawner.spawn(board: board, random: random);

      board = spawnedTile.board;
    }

    return GameState(board: board, configuration: configuration);
  }

  /// The current immutable board.
  final GameBoard board;

  /// The validated rules preserved across every move.
  final GameConfiguration configuration;

  /// Total points accumulated since the game began.
  final int score;

  /// Performs a move and returns its next state without event details.
  ///
  /// This delegates to [moveWithResult], so both methods have identical
  /// gameplay rules and random-number consumption.
  GameState move({required MoveDirection direction, required Random random}) {
    return moveWithResult(direction: direction, random: random).state;
  }

  /// Applies one movement direction and returns its state and event details.
  ///
  /// Steps: slide and merge tiles, return immediately for an unchanged board,
  /// spawn one tile, award points, and construct the next immutable state.
  GameMoveResult moveWithResult({
    required MoveDirection direction,
    required Random random,
  }) {
    final boardMovement = BoardMovement(
      maxTileLevel: configuration.maxTileLevel,
    );

    final movementResult = boardMovement.move(
      board: board,
      direction: direction,
    );

    if (movementResult.board == board) {
      return GameMoveResult._(
        state: this,
        changed: false,
        scoreGained: 0,
        movements: const [],
        merges: const [],
      );
    }

    final tileSpawner = TileSpawner(spawnWeights: configuration.spawnWeights);

    final spawnResult = tileSpawner.spawn(
      board: movementResult.board,
      random: random,
    );

    var scoreGained = 0;

    for (final merge in movementResult.merges) {
      scoreGained +=
          configuration.mergeScoreMultiplier * merge.level * merge.level;
    }

    final nextState = GameState(
      board: spawnResult.board,
      configuration: configuration,
      score: score + scoreGained,
    );

    return GameMoveResult._(
      state: nextState,
      changed: true,
      scoreGained: scoreGained,
      movements: movementResult.movements,
      merges: movementResult.merges,
      spawnedTile: spawnResult.event,
    );
  }
}
