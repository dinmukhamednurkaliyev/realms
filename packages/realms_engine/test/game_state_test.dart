import 'package:realms_engine/src/direction.dart';
import 'package:realms_engine/src/game_board.dart';
import 'package:realms_engine/src/game_state.dart';
import 'package:test/test.dart';

void main() {
  group('GameState', () {
    test('moves and merges tiles to the left', () {
      final state = GameState(boardWithFirstRow([2, null, 2, 4]));

      final nextState = state.move(Direction.left);

      expect(nextState.board.rows.first, [4, 4, null, null]);

      expect(state.board.rows.first, [2, null, 2, 4]);
    });

    test('moves and merges tiles to the right', () {
      final state = GameState(boardWithFirstRow([2, null, 2, 4]));

      final nextState = state.move(Direction.right);

      expect(nextState.board.rows.first, [null, null, 4, 4]);
    });

    test('moves and merges tiles upward', () {
      final state = GameState(
        GameBoard([
          [2, null, null, null],
          [2, null, null, null],
          [null, null, null, null],
          [null, null, null, null],
        ]),
      );

      final nextState = state.move(Direction.up);

      expect(nextState.board.tileAt(0, 0), 4);
      expect(nextState.board.tileAt(1, 0), isNull);
    });

    test('moves and merges tiles downward', () {
      final state = GameState(
        GameBoard([
          [2, null, null, null],
          [2, null, null, null],
          [null, null, null, null],
          [null, null, null, null],
        ]),
      );

      final nextState = state.move(Direction.down);

      expect(nextState.board.tileAt(2, 0), isNull);
      expect(nextState.board.tileAt(3, 0), 4);
    });

    test('does not merge a tile twice in one move', () {
      final state = GameState(boardWithFirstRow([2, 2, 4, null]));

      final nextState = state.move(Direction.left);

      expect(nextState.board.rows.first, [4, 4, null, null]);
    });

    test('merges two independent pairs', () {
      final state = GameState(boardWithFirstRow([2, 2, 2, 2]));

      final nextState = state.move(Direction.left);

      expect(nextState.board.rows.first, [4, 4, null, null]);
    });

    test('returns the same state when nothing moves', () {
      final state = GameState(boardWithFirstRow([2, 4, 8, 16]));

      final nextState = state.move(Direction.left);

      expect(identical(nextState, state), isTrue);
    });
  });
}

GameBoard boardWithFirstRow(List<int?> row) {
  return GameBoard([
    row,
    [null, null, null, null],
    [null, null, null, null],
    [null, null, null, null],
  ]);
}
