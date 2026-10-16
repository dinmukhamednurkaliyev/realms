import 'package:engine/engine.dart';
import 'package:test/test.dart';

void main() {
  group('GameBoard', () {
    for (final rowCount in [0, 3, 5]) {
      test('rejects $rowCount rows', () {
        expect(
          () => GameBoard(
            List.generate(rowCount, (_) => List<int?>.filled(4, null)),
          ),
          throwsArgumentError,
        );
      });
    }

    for (var rowIndex = 0; rowIndex < GameBoard.dimension; rowIndex++) {
      for (final columnCount in [0, 3, 5]) {
        test('rejects $columnCount columns in row $rowIndex', () {
          final rows = _emptyRows();
          rows[rowIndex] = List<int?>.filled(columnCount, null);

          expect(() => GameBoard(rows), throwsArgumentError);
        });
      }
    }

    test('provides access to tiles by position', () {
      final board = GameBoard([
        [2, 4, null, null],
        [null, null, null, null],
        [null, null, null, null],
        [null, null, null, 8],
      ]);

      expect(board.tileAt(0, 0), 2);
      expect(board.tileAt(0, 1), 4);
      expect(board.tileAt(0, 2), isNull);
      expect(board.tileAt(3, 3), 8);
    });

    for (final (row, column) in [(-1, 0), (4, 0), (0, -1), (0, 4)]) {
      test('rejects coordinates ($row, $column)', () {
        final board = GameBoard(_emptyRows());

        expect(() => board.tileAt(row, column), throwsRangeError);
      });
    }

    test('preserves arbitrary integers and distinguishes zero from empty', () {
      final rows = _emptyRows();
      rows[0] = [0, -2, 1, 3];
      final board = GameBoard(rows);

      expect(board.rows, rows);
      expect(board.tileAt(0, 0), 0);
      expect(board.tileAt(1, 0), isNull);
    });

    test('copies both the outer list and each row', () {
      final rows = _emptyRows();
      final board = GameBoard(rows);

      rows[0][0] = 2;
      rows[1] = [4, 4, 4, 4];
      rows.clear();

      expect(board.rows, _emptyRows());
    });

    test('copies shared input rows', () {
      final row = <int?>[2, null, null, null];
      final board = GameBoard(List.filled(GameBoard.dimension, row));

      row[0] = 4;

      expect(board.rows, List.filled(4, [2, null, null, null]));
    });

    test('prevents external modifications at both list levels', () {
      final board = GameBoard(_emptyRows());

      expect(() => board.rows[0][0] = 4, throwsUnsupportedError);
      expect(() => board.rows[0].add(4), throwsUnsupportedError);
      expect(() => board.rows[0].clear(), throwsUnsupportedError);
      expect(() => board.rows[0] = [2, 4, 8, 16], throwsUnsupportedError);
      expect(() => board.rows.add([2, 4, 8, 16]), throwsUnsupportedError);
      expect(() => board.rows.clear(), throwsUnsupportedError);
      expect(board.rows, _emptyRows());
    });

    group('value equality', () {
      test('is reflexive, symmetric and transitive with matching hashes', () {
        final rows = _emptyRows();
        rows[0] = [2, 4, null, null];
        final first = GameBoard(rows);
        final second = GameBoard(rows);
        final third = GameBoard(rows);

        expect(first, same(first));
        expect(first == first, isTrue);
        expect(first == second, isTrue);
        expect(second == first, isTrue);
        expect(second == third, isTrue);
        expect(first == third, isTrue);
        expect(first.hashCode, second.hashCode);
        expect(second.hashCode, third.hashCode);
        expect({first, second, third}, hasLength(1));
        expect({first: 'saved'}[second], 'saved');
      });

      for (var row = 0; row < GameBoard.dimension; row++) {
        for (var column = 0; column < GameBoard.dimension; column++) {
          test('includes cell ($row, $column)', () {
            final empty = GameBoard(_emptyRows());
            final rows = _emptyRows();
            rows[row][column] = 0;
            final occupied = GameBoard(rows);

            expect(empty == occupied, isFalse);
            expect(occupied == empty, isFalse);
          });
        }
      }

      test('compares tile values and positions', () {
        final firstRows = _emptyRows();
        firstRows[0] = [2, 4, null, null];
        final differentRows = _emptyRows();
        differentRows[0] = [4, 2, null, null];

        expect(GameBoard(firstRows), isNot(GameBoard(differentRows)));
      });

      test('does not equate a board with its raw rows or another object', () {
        final rows = _emptyRows();
        final Object rawRows = rows;
        final board = GameBoard(rows);

        expect(board == rawRows, isFalse);
        expect(board == Object(), isFalse);
      });

      test('remains stable after the constructor input changes', () {
        final rows = _emptyRows();
        final board = GameBoard(rows);
        final equalBoard = GameBoard(rows);
        final saved = {board: 'saved'};
        final hash = board.hashCode;

        rows[0][0] = 4;
        rows.clear();

        expect(board, equalBoard);
        expect(board.hashCode, hash);
        expect(saved[equalBoard], 'saved');
      });
    });
  });
}

List<List<int?>> _emptyRows() => List.generate(
  GameBoard.dimension,
  (_) => List<int?>.filled(GameBoard.dimension, null),
);
