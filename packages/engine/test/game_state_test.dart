import 'dart:math';

import 'package:engine/engine.dart';
import 'package:test/test.dart';

const _classicBoardSize = 4;

void main() {
  group('GameState.start', () {
    test('creates configured initial tiles', () {
      final configuration = GameConfiguration(rowCount: 2, columnCount: 2);

      final random = _ControlledRandom();

      final state = GameState.start(
        configuration: configuration,
        random: random,
      );

      expect(state.board.rows, [
        [null, null],
        [2, 2],
      ]);

      expect(random.calls, [
        'nextInt(4)',
        'nextDouble',
        'nextInt(3)',
        'nextDouble',
      ]);
    });
  });
  group('GameState.move', () {
    final lineCases = <({String name, List<int?> input, List<int?> output})>[
      (
        name: 'slides across empty cells',
        input: [null, 2, null, 4],
        output: [2, 4, null, null],
      ),
      (
        name: 'merges across empty cells',
        input: [2, null, 2, 4],
        output: [4, 4, null, null],
      ),
      (
        name: 'merges the pair nearest the destination first',
        input: [2, 2, 2, null],
        output: [4, 2, null, null],
      ),
      (
        name: 'merges two independent equal pairs',
        input: [2, 2, 2, 2],
        output: [4, 4, null, null],
      ),
      (
        name: 'does not merge a newly formed tile again',
        input: [2, 2, 4, null],
        output: [4, 4, null, null],
      ),
      (
        name: 'merges two independent different pairs',
        input: [4, 4, 8, 8],
        output: [8, 16, null, null],
      ),
      (
        name: 'does not merge tiles separated by another value',
        input: [2, 4, 4, 2],
        output: [2, 8, 2, null],
      ),
      (
        name: 'does not merge a new tile with either neighbor',
        input: [4, 2, 2, 4],
        output: [4, 4, 4, null],
      ),
      (
        name: 'preserves merging of zero and negative tiles',
        input: [0, 0, -2, -2],
        output: [0, -4, null, null],
      ),
      (
        name: 'preserves merging of arbitrary integer tiles',
        input: [1, 1, 3, 3],
        output: [2, 6, null, null],
      ),
    ];

    for (final direction in MoveDirection.values) {
      group(direction.name, () {
        for (final testCase in lineCases) {
          test(testCase.name, () {
            final originalRows = _rowsWithLine(testCase.input, direction);
            final state = GameState(GameBoard(originalRows));
            final expectedRows = _rowsWithLine(testCase.output, direction);

            expectedRows[3][3] = 2;

            final next = state.move(direction, random: _ControlledRandom());

            expect(next.board.rows, expectedRows);
            expect(next, isNot(same(state)));
            expect(state.board.rows, originalRows);
          });
        }

        test('leaves an empty board and random source unchanged', () {
          final state = GameState(GameBoard(_emptyRows()));
          final random = _ControlledRandom();

          expect(state.move(direction, random: random), same(state));
          expect(random.calls, isEmpty);
        });

        test('leaves a settled line and random source unchanged', () {
          final state = GameState(
            GameBoard(_rowsWithLine([2, 4, 8, 16], direction)),
          );
          final random = _ControlledRandom();

          expect(state.move(direction, random: random), same(state));
          expect(random.calls, isEmpty);
        });

        test('leaves a blocked full board and random source unchanged', () {
          final state = GameState(
            GameBoard([
              [2, 4, 2, 4],
              [4, 2, 4, 2],
              [2, 4, 2, 4],
              [4, 2, 4, 2],
            ]),
          );
          final random = _ControlledRandom();

          expect(state.move(direction, random: random), same(state));
          expect(random.calls, isEmpty);
        });
      });
    }

    group('multiple rows and columns', () {
      final horizontalRows = <List<int?>>[
        [2, null, 2, 4],
        [2, 2, 2, 2],
        [4, 4, 8, 8],
        [null, null, null, null],
      ];

      final verticalRows = <List<int?>>[
        [2, null, 4, null],
        [2, 4, 4, null],
        [4, 4, null, 8],
        [4, null, null, 8],
      ];

      final cases = [
        (
          direction: MoveDirection.left,
          input: horizontalRows,
          expected: <List<int?>>[
            [4, 4, null, null],
            [4, 4, null, null],
            [8, 16, null, null],
            [null, null, null, 2],
          ],
        ),
        (
          direction: MoveDirection.right,
          input: horizontalRows,
          expected: <List<int?>>[
            [null, null, 4, 4],
            [null, null, 4, 4],
            [null, null, 8, 16],
            [null, null, null, 2],
          ],
        ),
        (
          direction: MoveDirection.up,
          input: verticalRows,
          expected: <List<int?>>[
            [4, 8, 8, 16],
            [8, null, null, null],
            [null, null, null, null],
            [null, null, null, 2],
          ],
        ),
        (
          direction: MoveDirection.down,
          input: verticalRows,
          expected: <List<int?>>[
            [null, null, null, null],
            [null, null, null, null],
            [4, null, null, 2],
            [8, 8, 8, 16],
          ],
        ),
      ];

      for (final testCase in cases) {
        test(testCase.direction.name, () {
          final state = GameState(GameBoard(testCase.input));

          final next = state.move(
            testCase.direction,
            random: _ControlledRandom(),
          );

          expect(next.board.rows, testCase.expected);
          expect(state.board.rows, testCase.input);
        });
      }
    });

    group('variable board dimensions', () {
      test('moves and spawns on a 5x5 board', () {
        final state = GameState(
          GameBoard([
            [2, null, 2, null, 4],
            [null, null, null, null, null],
            [null, null, null, null, null],
            [null, null, null, null, null],
            [null, null, null, null, null],
          ]),
        );

        final next = state.move(
          MoveDirection.left,
          random: _ControlledRandom(),
        );

        expect(next.board.rows, [
          [4, 4, null, null, null],
          [null, null, null, null, null],
          [null, null, null, null, null],
          [null, null, null, null, null],
          [null, null, null, null, 2],
        ]);
      });

      test('moves vertically on a rectangular 4x6 board', () {
        final state = GameState(
          GameBoard([
            [2, null, null, null, null, null],
            [2, null, null, null, null, null],
            [null, null, null, null, null, null],
            [null, null, null, null, null, null],
          ]),
        );

        final next = state.move(
          MoveDirection.down,
          random: _ControlledRandom(),
        );

        expect(next.board.rows, [
          [null, null, null, null, null, null],
          [null, null, null, null, null, null],
          [null, null, null, null, null, null],
          [4, null, null, null, null, 2],
        ]);
      });
    });

    group('spawning', () {
      for (var position = 0; position < 14; position++) {
        test('selects empty cell $position in row order', () {
          final state = GameState(
            GameBoard(_rowsWithLine([null, 2, 4, null], MoveDirection.left)),
          );

          final random = _ControlledRandom(position: position);

          final expectedRows = _rowsWithLine([
            2,
            4,
            null,
            null,
          ], MoveDirection.left);

          final cell = position + 2;
          expectedRows[cell ~/ _classicBoardSize][cell % _classicBoardSize] = 2;

          final next = state.move(MoveDirection.left, random: random);

          expect(next.board.rows, expectedRows);
          expect(random.calls, ['nextInt(14)', 'nextDouble']);
        });
      }

      for (final (roll, value) in [
        (0.0, 2),
        (0.899999999, 2),
        (0.9, 4),
        (0.999999999, 4),
      ]) {
        test('spawns $value for a random value of $roll', () {
          final state = GameState(
            GameBoard(_rowsWithLine([null, 2, 4, null], MoveDirection.left)),
          );

          final random = _ControlledRandom(tileRoll: roll);

          final expectedRows = _rowsWithLine([
            2,
            4,
            null,
            null,
          ], MoveDirection.left);

          expectedRows[3][3] = value;

          final next = state.move(MoveDirection.left, random: random);

          expect(next.board.rows, expectedRows);
          expect(random.calls, ['nextInt(14)', 'nextDouble']);
        });
      }

      test('uses the only cell freed by a merge on a full board', () {
        final state = GameState(
          GameBoard([
            [2, 2, 8, 16],
            [4, 8, 16, 32],
            [8, 16, 32, 64],
            [16, 32, 64, 128],
          ]),
        );

        final random = _ControlledRandom(tileRoll: 0.9);

        final next = state.move(MoveDirection.left, random: random);

        expect(next.board.rows, [
          [4, 8, 16, 4],
          [4, 8, 16, 32],
          [8, 16, 32, 64],
          [16, 32, 64, 128],
        ]);

        expect(random.calls, ['nextInt(1)', 'nextDouble']);
      });
    });

    test('replays a sequence with equivalent random sources', () {
      final initial = GameState(
        GameBoard(_rowsWithLine([2, null, 2, 4], MoveDirection.left)),
      );

      var first = initial;
      var second = initial;

      final firstRandom = Random(42);
      final secondRandom = Random(42);

      for (var turn = 0; turn < 100; turn++) {
        final direction =
            MoveDirection.values[turn % MoveDirection.values.length];

        first = first.move(direction, random: firstRandom);
        second = second.move(direction, random: secondRandom);

        expect(first.board.rows, second.board.rows);
      }

      expect(firstRandom.nextDouble(), secondRandom.nextDouble());
      expect(initial.board.rows.first, [2, null, 2, 4]);
    });

    test('retained states stay unchanged through subsequent moves', () {
      var state = GameState(
        GameBoard(_rowsWithLine([2, null, 2, 4], MoveDirection.left)),
      );

      final history = <({GameState state, List<List<int?>> rows})>[];
      final random = Random(42);

      for (final direction in MoveDirection.values) {
        history.add((
          state: state,
          rows: [
            for (final row in state.board.rows) [...row],
          ],
        ));

        state = state.move(direction, random: random);
      }

      for (final snapshot in history) {
        expect(snapshot.state.board.rows, snapshot.rows);
      }
    });
  });
}

List<List<int?>> _emptyRows() => List.generate(
  _classicBoardSize,
  (_) => List<int?>.filled(_classicBoardSize, null),
);

List<List<int?>> _rowsWithLine(List<int?> tiles, MoveDirection direction) {
  final rows = _emptyRows();

  for (var index = 0; index < _classicBoardSize; index++) {
    switch (direction) {
      case MoveDirection.left:
        rows[0][index] = tiles[index];
      case MoveDirection.right:
        rows[0][_classicBoardSize - 1 - index] = tiles[index];
      case MoveDirection.up:
        rows[index][0] = tiles[index];
      case MoveDirection.down:
        rows[_classicBoardSize - 1 - index][0] = tiles[index];
    }
  }

  return rows;
}

final class _ControlledRandom implements Random {
  new({this.position, this.tileRoll = 0});

  final int? position;
  final double tileRoll;
  final calls = <String>[];

  @override
  int nextInt(int max) {
    calls.add('nextInt($max)');
    return position ?? max - 1;
  }

  @override
  double nextDouble() {
    calls.add('nextDouble');
    return tileRoll;
  }

  @override
  bool nextBool() {
    throw UnsupportedError('Unexpected random boolean draw.');
  }
}
