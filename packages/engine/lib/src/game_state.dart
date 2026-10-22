import 'dart:math';

import 'package:engine/src/game_board.dart';
import 'package:engine/src/game_configuration.dart';
import 'package:engine/src/move_direction.dart';

final class GameState {
  const new(this.board);

  factory start({
    required GameConfiguration configuration,
    required Random random,
  }) {
    var board = GameBoard.empty(
      rowCount: configuration.rowCount,
      columnCount: configuration.columnCount,
    );

    for (var index = 0; index < configuration.initialTileCount; index++) {
      board = _spawnTile(board, random);
    }

    return GameState(board);
  }

  final GameBoard board;

  /// Slides and merges tiles, then spawns one tile only if the board changed.
  ///
  /// Returns this state without drawing from [random] when nothing moves.
  /// The caller owns [random]; reuse it across turns to advance its sequence.
  GameState move(MoveDirection direction, {required Random random}) {
    final movedBoard = _moveBoard(board, direction);

    if (board == movedBoard) {
      return this;
    }

    final nextBoard = _spawnTile(movedBoard, random);

    return GameState(nextBoard);
  }
}

GameBoard _moveBoard(GameBoard board, MoveDirection direction) {
  return GameBoard(switch (direction) {
    MoveDirection.left => _moveLeft(board.rows),
    MoveDirection.right => _moveRight(board.rows),
    MoveDirection.up => _moveUp(board.rows),
    MoveDirection.down => _moveDown(board.rows),
  });
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

GameBoard _spawnTile(GameBoard board, Random random) {
  final emptyPositions = <({int rowIndex, int columnIndex})>[];

  for (var rowIndex = 0; rowIndex < board.rowCount; rowIndex++) {
    for (var columnIndex = 0; columnIndex < board.columnCount; columnIndex++) {
      if (board.tileAt(rowIndex, columnIndex) == null) {
        emptyPositions.add((rowIndex: rowIndex, columnIndex: columnIndex));
      }
    }
  }

  if (emptyPositions.isEmpty) {
    throw StateError('Cannot spawn a tile on a full board.');
  }

  final position = emptyPositions[random.nextInt(emptyPositions.length)];
  final value = random.nextDouble() < 0.9 ? 2 : 4;

  final nextRows = <List<int?>>[
    for (final row in board.rows) [...row],
  ];

  nextRows[position.rowIndex][position.columnIndex] = value;

  return GameBoard(nextRows);
}
