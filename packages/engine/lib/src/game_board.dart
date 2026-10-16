/// An immutable 4x4 grid, compared by tile values. Null denotes an empty cell.
///
/// Integer tile values are preserved as supplied.
final class GameBoard {
  new(List<List<int?>> rows)
    : _rows = List<List<int?>>.unmodifiable(rows.map(List<int?>.unmodifiable)) {
    if (_rows.length != dimension ||
        _rows.any((row) => row.length != dimension)) {
      throw ArgumentError('Game board must be 4x4.');
    }
  }

  static const dimension = 4;

  final List<List<int?>> _rows;

  List<List<int?>> get rows => _rows;

  int? tileAt(int rowIndex, int columnIndex) {
    return _rows[rowIndex][columnIndex];
  }

  @override
  // Both list levels are frozen; an annotation dependency is unnecessary.
  // ignore: avoid_equals_and_hash_code_on_mutable_classes
  bool operator ==(Object other) {
    if (identical(this, other)) {
      return true;
    }
    if (other is! GameBoard) {
      return false;
    }

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

  @override
  // The hash depends only on the deeply immutable grid.
  // ignore: avoid_equals_and_hash_code_on_mutable_classes
  int get hashCode => Object.hashAll(_rows.expand((row) => row));
}
