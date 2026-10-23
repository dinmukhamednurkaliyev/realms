/// An immutable rectangular grid, compared by tile values.
///
/// Null denotes an empty cell.
/// Integer tile values are preserved as supplied.
final class GameBoard {
  new({required List<List<int?>> rows})
    : _rows = List<List<int?>>.unmodifiable(rows.map(List<int?>.unmodifiable)) {
    if (_rows.isEmpty ||
        _rows.first.isEmpty ||
        _rows.any((row) => row.length != _rows.first.length)) {
      throw ArgumentError('Game board must be a non-empty rectangular grid.');
    }
  }

  factory empty({required int rowCount, required int columnCount}) {
    if (rowCount <= 0 || columnCount <= 0) {
      throw ArgumentError('Game board dimensions must be positive.');
    }

    return GameBoard(
      rows: List.generate(
        rowCount,
        (_) => List<int?>.filled(columnCount, null),
      ),
    );
  }

  final List<List<int?>> _rows;

  int get rowCount => _rows.length;

  int get columnCount => _rows.first.length;

  List<List<int?>> get rows => _rows;

  int? tileAt({required int rowIndex, required int columnIndex}) {
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

    if (rowCount != other.rowCount || columnCount != other.columnCount) {
      return false;
    }

    for (var rowIndex = 0; rowIndex < rowCount; rowIndex++) {
      for (var columnIndex = 0; columnIndex < columnCount; columnIndex++) {
        if (tileAt(rowIndex: rowIndex, columnIndex: columnIndex) !=
            other.tileAt(rowIndex: rowIndex, columnIndex: columnIndex)) {
          return false;
        }
      }
    }

    return true;
  }

  @override
  // The hash depends only on the deeply immutable grid.
  // ignore: avoid_equals_and_hash_code_on_mutable_classes
  int get hashCode => Object.hash(
    rowCount,
    columnCount,
    Object.hashAll(_rows.expand((row) => row)),
  );
}
