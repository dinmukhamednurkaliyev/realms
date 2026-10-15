import 'package:realms_engine/src/direction.dart';

List<List<int?>> moveBoard(List<List<int?>> board, Direction direction) {
  return switch (direction) {
    Direction.left => _moveLeft(board),
    Direction.right => _moveRight(board),
    Direction.up => _moveUp(board),
    Direction.down => _moveDown(board),
  };
}

List<int?> _mergeRow(List<int?> row) {
  final tiles = row.whereType<int>().toList();

  final result = <int?>[];
  var index = 0;

  while (index < tiles.length) {
    final current = tiles[index];

    if (index + 1 < tiles.length && current == tiles[index + 1]) {
      result.add(current * 2);
      index += 2;
    } else {
      result.add(current);
      index += 1;
    }
  }

  while (result.length < row.length) {
    result.add(null);
  }

  return result;
}

List<List<int?>> _moveLeft(List<List<int?>> board) {
  final movedBoard = <List<int?>>[];

  for (final row in board) {
    movedBoard.add(_mergeRow(row));
  }

  return movedBoard;
}

List<List<int?>> _moveRight(List<List<int?>> board) {
  final movedBoard = <List<int?>>[];

  for (final row in board) {
    final reversedRow = row.reversed.toList();
    final mergedRow = _mergeRow(reversedRow);

    movedBoard.add(mergedRow.reversed.toList());
  }

  return movedBoard;
}

List<List<int?>> _moveUp(List<List<int?>> board) {
  final columns = _transpose(board);
  final movedColumns = _moveLeft(columns);

  return _transpose(movedColumns);
}

List<List<int?>> _moveDown(List<List<int?>> board) {
  final columns = _transpose(board);
  final movedColumns = _moveRight(columns);

  return _transpose(movedColumns);
}

List<List<int?>> _transpose(List<List<int?>> board) {
  final transposedBoard = <List<int?>>[];

  for (var columnIndex = 0; columnIndex < board.first.length; columnIndex++) {
    final column = <int?>[];

    for (var rowIndex = 0; rowIndex < board.length; rowIndex++) {
      column.add(board[rowIndex][columnIndex]);
    }

    transposedBoard.add(column);
  }

  return transposedBoard;
}
