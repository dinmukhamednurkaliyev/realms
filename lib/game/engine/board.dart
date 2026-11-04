/// A zero-based position on a game board.
///
/// Identifies a cell whether it contains a tile or is empty.
/// The `rowIndex` increases downward; `columnIndex` increases rightward.
typedef BoardPosition = ({int rowIndex, int columnIndex});

/// An immutable, non-empty rectangular grid of tile levels.
///
/// A `null` cell is empty. The board preserves any supplied integer, leaving
/// the validation of playable tile levels to `GameState`.
/// Two boards are equal when they have the same shape and cell values.
final class GameBoard {
  /// Creates a board by deeply copying and freezing [rows].
  ///
  /// Throws an [ArgumentError] if the grid is empty or not rectangular.
  new({required List<List<int?>> rows})
    : _rows = List<List<int?>>.unmodifiable(rows.map(List<int?>.unmodifiable)) {
    if (_rows.isEmpty ||
        _rows.first.isEmpty ||
        _rows.any((row) => row.length != _rows.first.length)) {
      throw ArgumentError('Game board must be a non-empty rectangular grid.');
    }
  }

  /// Creates an empty board with the requested number of rows and columns.
  ///
  /// Throws an [ArgumentError] when either dimension is not positive.
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

  /// The number of horizontal rows in the board.
  int get rowCount => _rows.length;

  /// The number of cells in every row.
  int get columnCount => _rows.first.length;

  /// An unmodifiable view of the board, including its individual rows.
  List<List<int?>> get rows => _rows;

  /// Returns the level at the given zero-based indices, or `null` if empty.
  ///
  /// Throws a [RangeError] if either index falls outside the board.
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
