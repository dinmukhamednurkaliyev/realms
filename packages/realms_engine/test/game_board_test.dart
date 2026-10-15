import 'package:realms_engine/src/game_board.dart';
import 'package:test/test.dart';

void main() {
  group('Board', () {
    test('rejects invalid board dimensions', () {
      expect(
        () => GameBoard([
          [2, 2],
          [4, 4],
        ]),
        throwsArgumentError,
      );
    });

    test('copies the original rows', () {
      final rows = List.generate(
        GameBoard.dimension,
        (_) => List<int?>.filled(GameBoard.dimension, null),
      );

      final board = GameBoard(rows);

      rows[0][0] = 2;

      expect(board.tileAt(0, 0), isNull);
    });

    test('prevents external modifications', () {
      final board = GameBoard(
        List.generate(
          GameBoard.dimension,
          (_) => List<int?>.filled(GameBoard.dimension, null),
        ),
      );

      expect(() => board.rows[0][0] = 4, throwsUnsupportedError);

      expect(() => board.rows.clear(), throwsUnsupportedError);
    });

    test('compares boards by their tile values', () {
      final first = GameBoard([
        [2, 4, null, null],
        [null, null, null, null],
        [null, null, null, null],
        [null, null, null, null],
      ]);

      final second = GameBoard([
        [2, 4, null, null],
        [null, null, null, null],
        [null, null, null, null],
        [null, null, null, null],
      ]);

      expect(first.hasSameTilesAs(second), isTrue);
    });
  });
}
