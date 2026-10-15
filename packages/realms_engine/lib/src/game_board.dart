final class GameBoard {
  new(List<List<int?>> rows)
    : _rows = List<List<int?>>.unmodifiable(rows.map(List<int?>.unmodifiable)) {
    if (_rows.length != dimension ||
        _rows.any((row) => row.length != dimension)) {
      throw ArgumentError('Board must have 4 rows and 4 columns.');
    }
  }

  static const dimension = 4;

  final List<List<int?>> _rows;

  List<List<int?>> get rows => _rows;

  int? tileAt(int rowIndex, int columnIndex) {
    return _rows[rowIndex][columnIndex];
  }

  bool hasSameTilesAs(GameBoard other) {
    for (var rowIndex = 0; rowIndex < dimension; rowIndex++) {
      for (var columnIndex = 0; columnIndex < dimension; columnIndex++) {
        if (tileAt(rowIndex, columnIndex) !=
            other.tileAt(rowIndex, columnIndex)) {
          return false;
        }
      }
    }

    return true;
  }
}
