final class GameConfiguration {
  new({
    this.rowCount = 4,
    this.columnCount = 4,
    this.initialTileCount = 2,
    Map<int, int> spawnWeights = const {2: 9, 4: 1},
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

    if (this.spawnWeights.isEmpty ||
        this.spawnWeights.entries.any(
          (entry) => entry.key <= 0 || entry.value <= 0,
        )) {
      throw ArgumentError('Spawn values and weights must be positive.');
    }
  }

  final int rowCount;
  final int columnCount;
  final int initialTileCount;
  final Map<int, int> spawnWeights;
}
