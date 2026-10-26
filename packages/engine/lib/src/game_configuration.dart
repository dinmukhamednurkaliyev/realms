final class GameConfiguration {
  new({
    this.rowCount = 4,
    this.columnCount = 4,
    this.initialTileCount = 2,
    this.maxTileLevel = 50,
    this.mergeScoreMultiplier = 10,
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

  final int rowCount;
  final int columnCount;
  final int initialTileCount;
  final int maxTileLevel;
  final int mergeScoreMultiplier;

  /// An immutable map of relative spawn weights by tile level.
  ///
  /// Iteration order is preserved from the supplied map and affects which
  /// level a given random draw selects.
  final Map<int, int> spawnWeights;
}
