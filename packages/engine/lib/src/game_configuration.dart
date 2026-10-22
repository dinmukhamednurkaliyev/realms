final class GameConfiguration {
  new({this.rowCount = 4, this.columnCount = 4, this.initialTileCount = 2}) {
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
  }

  final int rowCount;
  final int columnCount;
  final int initialTileCount;
}
