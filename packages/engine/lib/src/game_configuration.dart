final class GameConfiguration {
  new({this.rowCount = 4, this.columnCount = 4}) {
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
  }

  final int rowCount;
  final int columnCount;
}
