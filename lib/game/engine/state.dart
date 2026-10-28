import 'dart:math';

import 'package:realms/game/engine/board.dart';
import 'package:realms/game/engine/configuration.dart';
import 'package:realms/game/engine/events.dart';
import 'package:realms/game/engine/mechanics.dart' as mechanics;

/// The current evaluation of victory and move availability.
///
/// Completing an objective takes priority over defeat.
enum GameStatus {
  /// No objective has been completed and at least one move is available.
  inProgress,

  /// The configured game objective has been completed.
  won,

  /// No objective has been completed and no legal move remains.
  lost,
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
      for (final tileLevel in row) {
        if (tileLevel != null &&
            (tileLevel < 1 || tileLevel > this.configuration.maxTileLevel)) {
          throw ArgumentError.value(
            tileLevel,
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
    var initialBoard = GameBoard.empty(
      rowCount: configuration.rowCount,
      columnCount: configuration.columnCount,
    );

    for (
      var tileIndex = 0;
      tileIndex < configuration.initialTileCount;
      tileIndex++
    ) {
      final spawnResult = mechanics.spawnTile(
        board: initialBoard,
        random: random,
        spawnWeights: configuration.spawnWeights,
      );
      initialBoard = spawnResult.board;
    }

    return GameState(board: initialBoard, configuration: configuration);
  }

  /// The current immutable board.
  final GameBoard board;

  /// The validated rules preserved across every move.
  final GameConfiguration configuration;

  /// Total points accumulated since the game began.
  final int score;

  /// Whether any movement direction can change the current board.
  ///
  /// Uses the same merge rules as [moveWithResult], including the maximum
  /// tile level. Checks adjacent cells without constructing a moved board,
  /// producing events, or using randomness.
  /// An entirely empty board has no available moves.
  bool get hasAvailableMoves => mechanics.hasAvailableMoves(
    board: board,
    maxTileLevel: configuration.maxTileLevel,
  );

  /// Whether the configured victory objective is satisfied.
  ///
  /// Returns `false` when no objective is configured, as in Endless mode.
  /// Completing the objective does not prevent further moves; [status]
  /// and [isGameOver] report that the objective has ended the game.
  bool get hasCompletedObjective =>
      configuration.objective?.isCompleted(board: board, score: score) ?? false;

  /// Whether the game is ongoing, won, or lost at this snapshot.
  ///
  /// Completing the configured objective takes priority over having no
  /// available moves. A game without an objective can never be won.
  /// This getter is pure and does not consume randomness.
  GameStatus get status {
    if (hasCompletedObjective) {
      return GameStatus.won;
    }

    if (!hasAvailableMoves) {
      return GameStatus.lost;
    }

    return GameStatus.inProgress;
  }

  /// Whether the game has ended in either victory or defeat.
  ///
  /// A victory can occur while moves remain available. The movement methods
  /// do not themselves prevent moves after victory; callers decide whether
  /// to allow continued play.
  bool get isGameOver => status != GameStatus.inProgress;

  /// Performs a move and returns its next state without event details.
  ///
  /// Has the same gameplay rules and random draws as [moveWithResult].
  GameState move({
    required mechanics.MoveDirection direction,
    required Random random,
  }) {
    return moveWithResult(direction: direction, random: random).state;
  }

  /// Applies one movement direction and returns its state and event details.
  ///
  /// Steps: slide and merge tiles, return immediately for an unchanged board,
  /// spawn one tile, award points, and construct the next immutable state.
  GameMoveResult moveWithResult({
    required mechanics.MoveDirection direction,
    required Random random,
  }) {
    final movementResult = mechanics.moveBoard(
      board: board,
      direction: direction,
      maxTileLevel: configuration.maxTileLevel,
    );

    if (movementResult.board == board) {
      return GameMoveResult._(
        state: this,
        scoreGained: 0,
        movements: const [],
        merges: const [],
      );
    }

    final spawnResult = mechanics.spawnTile(
      board: movementResult.board,
      random: random,
      spawnWeights: configuration.spawnWeights,
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
      scoreGained: scoreGained,
      movements: movementResult.movements,
      merges: movementResult.merges,
      spawnedTile: spawnResult.spawnedTile,
    );
  }
}

/// The immutable result of one attempted move.
///
/// [state] is the resulting snapshot. An unchanged move retains the original
/// state, earns no points, emits no events, and consumes no random values.
/// A successful move currently spawns exactly one new tile.
final class GameMoveResult {
  new _({
    required this.state,
    required this.scoreGained,
    required List<TileMovement> movements,
    required List<TileMerge> merges,
    this.spawnedTile,
  }) : movements = List<TileMovement>.unmodifiable(movements),
       merges = List<TileMerge>.unmodifiable(merges),
       mergedLevels = List<int>.unmodifiable(
         merges.map((merge) => merge.level),
       );

  /// The next immutable state, or the original state for an unchanged move.
  final GameState state;

  /// Whether the attempted move changed the board.
  ///
  /// Derived from movement and merge events before spawning a new tile.
  bool get changed => movements.isNotEmpty || merges.isNotEmpty;

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
