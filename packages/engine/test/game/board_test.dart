import 'package:engine/engine.dart';
import 'package:test/test.dart';

const _classicBoardSize = 4;

void main() {
  test('BoardPosition and TilePosition work with occupied and empty cells', () {
    final board = GameBoard(
      rows: [
        [1, null],
      ],
    );
    const positions = <BoardPosition>[
      (rowIndex: 0, columnIndex: 0),
      (rowIndex: 0, columnIndex: 1),
    ];
    final compatiblePositions = <TilePosition>[...positions];
    final movement = TileMovement(
      from: compatiblePositions.first,
      to: compatiblePositions.last,
      level: 1,
    );

    expect(
      board.tileAt(
        rowIndex: movement.from.rowIndex,
        columnIndex: movement.from.columnIndex,
      ),
      1,
    );
    expect(
      board.tileAt(
        rowIndex: movement.to.rowIndex,
        columnIndex: movement.to.columnIndex,
      ),
      isNull,
    );
  });

  group('Board', () {
    test('rejects an empty board', () {
      expect(() => GameBoard(rows: []), throwsArgumentError);
    });

    for (final rowCount in [3, 5]) {
      test('supports $rowCount rows', () {
        final board = GameBoard(
          rows: List.generate(
            rowCount,
            (_) => List<int?>.filled(_classicBoardSize, null),
          ),
        );

        expect(board.rowCount, rowCount);
        expect(board.columnCount, _classicBoardSize);
      });
    }

    for (var rowIndex = 0; rowIndex < _classicBoardSize; rowIndex++) {
      for (final columnCount in [0, 3, 5]) {
        test('rejects $columnCount columns in row $rowIndex', () {
          final rows = _emptyRows();
          rows[rowIndex] = List<int?>.filled(columnCount, null);

          expect(() => GameBoard(rows: rows), throwsArgumentError);
        });
      }
    }

    test('provides access to tiles by position', () {
      final board = GameBoard(
        rows: [
          [2, 4, null, null],
          [null, null, null, null],
          [null, null, null, null],
          [null, null, null, 8],
        ],
      );

      expect(board.tileAt(rowIndex: 0, columnIndex: 0), 2);
      expect(board.tileAt(rowIndex: 0, columnIndex: 1), 4);
      expect(board.tileAt(rowIndex: 0, columnIndex: 2), isNull);
      expect(board.tileAt(rowIndex: 3, columnIndex: 3), 8);
    });

    for (final (rowIndex, columnIndex) in [(-1, 0), (4, 0), (0, -1), (0, 4)]) {
      test('rejects coordinates ($rowIndex, $columnIndex)', () {
        final board = GameBoard(rows: _emptyRows());

        expect(
          () => board.tileAt(rowIndex: rowIndex, columnIndex: columnIndex),
          throwsRangeError,
        );
      });
    }

    test('preserves arbitrary integers and distinguishes zero from empty', () {
      final rows = _emptyRows();
      rows[0] = [0, -2, 1, 3];

      final board = GameBoard(rows: rows);

      expect(board.rows, rows);
      expect(board.tileAt(rowIndex: 0, columnIndex: 0), 0);
      expect(board.tileAt(rowIndex: 1, columnIndex: 0), isNull);
    });

    test('copies both the outer list and each row', () {
      final rows = _emptyRows();
      final board = GameBoard(rows: rows);

      rows[0][0] = 2;
      rows[1] = [4, 4, 4, 4];
      rows.clear();

      expect(board.rows, _emptyRows());
    });

    test('copies shared input rows', () {
      final row = <int?>[2, null, null, null];
      final board = GameBoard(rows: List.filled(_classicBoardSize, row));

      row[0] = 4;

      expect(board.rows, List.filled(_classicBoardSize, [2, null, null, null]));
    });

    test('prevents external modifications at both list levels', () {
      final board = GameBoard(rows: _emptyRows());

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

        final first = GameBoard(rows: rows);
        final second = GameBoard(rows: rows);
        final third = GameBoard(rows: rows);

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

      for (var rowIndex = 0; rowIndex < _classicBoardSize; rowIndex++) {
        for (
          var columnIndex = 0;
          columnIndex < _classicBoardSize;
          columnIndex++
        ) {
          test('includes cell ($rowIndex, $columnIndex)', () {
            final empty = GameBoard(rows: _emptyRows());
            final rows = _emptyRows();
            rows[rowIndex][columnIndex] = 0;
            final occupied = GameBoard(rows: rows);

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

        expect(
          GameBoard(rows: firstRows),
          isNot(GameBoard(rows: differentRows)),
        );
      });

      test('distinguishes different board shapes', () {
        final first = GameBoard(
          rows: [
            [1, 2, 3, 4],
          ],
        );

        final second = GameBoard(
          rows: [
            [1, 2],
            [3, 4],
          ],
        );

        expect(first, isNot(second));
      });

      test('does not equate a board with raw rows or another object', () {
        final rows = _emptyRows();
        final Object rawRows = rows;
        final board = GameBoard(rows: rows);

        expect(board == rawRows, isFalse);
        expect(board == Object(), isFalse);
      });

      test('remains stable after constructor input changes', () {
        final rows = _emptyRows();
        final board = GameBoard(rows: rows);
        final equalBoard = GameBoard(rows: rows);
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

  group('Empty board construction', () {
    test('creates a rectangular board with every cell empty', () {
      final board = GameBoard.empty(rowCount: 2, columnCount: 3);

      expect(board.rows, [
        [null, null, null],
        [null, null, null],
      ]);
    });

    for (final (rowCount, columnCount) in [(0, 2), (-1, 2), (2, 0), (2, -1)]) {
      test('rejects dimensions ${rowCount}x$columnCount', () {
        expect(
          () => GameBoard.empty(rowCount: rowCount, columnCount: columnCount),
          throwsA(
            isA<ArgumentError>().having(
              (error) => error.message,
              'message',
              'Game board dimensions must be positive.',
            ),
          ),
        );
      });
    }
  });
}

List<List<int?>> _emptyRows() => List.generate(
  _classicBoardSize,
  (_) => List<int?>.filled(_classicBoardSize, null),
);
