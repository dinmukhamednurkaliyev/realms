import 'package:engine/src/game/objectives.dart';

/// Immutable rules used when starting, restoring, or progressing a game.
///
/// Board dimensions, merge limits, scoring, and tile spawning are fixed for
/// the lifetime of a game state. A configuration can be shared across states.
/// An optional [objective] defines success without changing movement rules.
/// These rules are shared across game modes, including Campaign and Endless.
final class GameConfiguration {
  /// Creates validated game rules, with 4x4 classic-style defaults.
  ///
  /// [spawnWeights] maps each possible initial tile level to a positive
  /// relative weight. Every spawn level must not exceed [maxTileLevel].
  /// The map is copied to prevent changes after construction.
  /// [objective] is optional, allowing Endless games without a victory target.
  ///
  /// To set [maxTileLevel] to 1, also supply a compatible weight map,
  /// such as `{1: 1}`, instead of relying on the default `{1: 9, 2: 1}`.
  new({
    this.rowCount = 4,
    this.columnCount = 4,
    this.initialTileCount = 2,
    this.maxTileLevel = 50,
    this.mergeScoreMultiplier = 10,
    this.objective,
    Map<int, int> spawnWeights = const {1: 9, 2: 1},
  }) : spawnWeights = Map<int, int>.unmodifiable(spawnWeights) {
    if (rowCount <= 0) {
      throw ArgumentError.value(
        rowCount,
        'rowCount',
        'Must be greater than zero.',
      );
    }

    if (columnCount <= 0) {
      throw ArgumentError.value(
        columnCount,
        'columnCount',
        'Must be greater than zero.',
      );
    }

    if (initialTileCount <= 0 || initialTileCount > rowCount * columnCount) {
      throw ArgumentError.value(
        initialTileCount,
        'initialTileCount',
        'Must be between 1 and the number of board cells.',
      );
    }

    if (maxTileLevel < 1) {
      throw ArgumentError.value(
        maxTileLevel,
        'maxTileLevel',
        'Must be greater than zero.',
      );
    }

    if (mergeScoreMultiplier <= 0) {
      throw ArgumentError.value(
        mergeScoreMultiplier,
        'mergeScoreMultiplier',
        'Must be greater than zero.',
      );
    }

    final configuredObjective = objective;

    if (configuredObjective is ReachTileLevelObjective &&
        configuredObjective.targetLevel > maxTileLevel) {
      throw ArgumentError.value(
        configuredObjective.targetLevel,
        'objective.targetLevel',
        'Must not exceed the maximum tile level.',
      );
    }

    if (this.spawnWeights.isEmpty ||
        this.spawnWeights.entries.any(
          (entry) =>
              entry.key < 1 || entry.key > maxTileLevel || entry.value <= 0,
        )) {
      throw ArgumentError(
        'Spawn levels must be within the evolution range '
        'and weights must be positive.',
      );
    }
  }

  /// Number of rows in the board.
  final int rowCount;

  /// Number of columns in the board.
  final int columnCount;

  /// Number of tiles placed at the beginning of a game.
  final int initialTileCount;

  /// Highest allowed tile level; tiles at this level cannot merge again.
  final int maxTileLevel;

  /// Multiplier for the points awarded by a merge.
  ///
  /// Merging into level `n` awards `mergeScoreMultiplier * n * n` points.
  final int mergeScoreMultiplier;

  /// Optional victory condition; `null` means there is no objective.
  ///
  /// This is independent of whether the board has any available moves.
  final GameObjective? objective;

  /// Immutable relative spawn weights, keyed by tile level.
  ///
  /// Map iteration order defines which levels correspond to each part of
  /// the weighted random range; preserve it for deterministic replays.
  final Map<int, int> spawnWeights;
}
