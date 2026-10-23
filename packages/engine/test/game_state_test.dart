import 'dart:math';

import 'package:engine/engine.dart';
import 'package:test/test.dart';

const _classicBoardSize = 4;

void main() {
  group('GameState.move', () {
    final lineCases = <({String name, List<int?> input, List<int?> output})>[
      (
        name: 'slides across empty cells',
        input: [null, 1, null, 2],
        output: [1, 2, null, null],
      ),
      (
        name: 'merges across empty cells',
        input: [1, null, 1, 2],
        output: [2, 2, null, null],
      ),
      (
        name: 'merges the pair nearest the destination first',
        input: [1, 1, 1, null],
        output: [2, 1, null, null],
      ),
      (
        name: 'merges two independent equal pairs',
        input: [1, 1, 1, 1],
        output: [2, 2, null, null],
      ),
      (
        name: 'does not merge a newly formed tile again',
        input: [1, 1, 2, null],
        output: [2, 2, null, null],
      ),
      (
        name: 'merges two independent different pairs',
        input: [2, 2, 3, 3],
        output: [3, 4, null, null],
      ),
      (
        name: 'does not merge tiles separated by another value',
        input: [1, 2, 2, 1],
        output: [1, 3, 1, null],
      ),
      (
        name: 'does not merge a new tile with either neighbor',
        input: [2, 1, 1, 2],
        output: [2, 2, 2, null],
      ),
      (
        name: 'supports higher evolution levels',
        input: [5, 5, 7, 7],
        output: [6, 8, null, null],
      ),
    ];

    for (final direction in MoveDirection.values) {
      group(direction.name, () {
        for (final testCase in lineCases) {
          test(testCase.name, () {
            final originalRows = _rowsWithLine(testCase.input, direction);

            final state = GameState(GameBoard(originalRows));

            final expectedRows = _rowsWithLine(testCase.output, direction);

            expectedRows[3][3] = 1;

            final next = state.move(direction, random: _ControlledRandom());

            expect(next.board.rows, expectedRows);
            expect(state.board.rows, originalRows);
            expect(next, isNot(same(state)));
          });
        }

        test('does not spawn when the board does not change', () {
          final state = GameState(
            GameBoard(_rowsWithLine([1, 2, 3, 4], direction)),
          );

          final random = _ControlledRandom();

          expect(state.move(direction, random: random), same(state));

          expect(random.calls, isEmpty);
        });

        test('does not spawn on an empty board', () {
          final state = GameState(GameBoard(_emptyRows()));
          final random = _ControlledRandom();

          expect(state.move(direction, random: random), same(state));

          expect(random.calls, isEmpty);
        });

        test('does not move a blocked full board', () {
          final state = GameState(
            GameBoard([
              [1, 2, 1, 2],
              [2, 1, 2, 1],
              [1, 2, 1, 2],
              [2, 1, 2, 1],
            ]),
          );

          final random = _ControlledRandom();

          expect(state.move(direction, random: random), same(state));

          expect(random.calls, isEmpty);
        });
      });
    }

    group('evolution limits', () {
      final configuration = GameConfiguration(
        rowCount: 1,
        maxTileLevel: 3,
        spawnWeights: {1: 1},
      );

      test('does not merge tiles at the maximum level', () {
        final state = GameState(
          GameBoard([
            [3, 3, null, null],
          ]),
          configuration: configuration,
        );

        final random = _ControlledRandom();

        expect(state.move(MoveDirection.left, random: random), same(state));

        expect(random.calls, isEmpty);
      });

      test('merges tiles below the maximum level', () {
        final state = GameState(
          GameBoard([
            [2, 2, null, null],
          ]),
          configuration: configuration,
        );

        final next = state.move(
          MoveDirection.left,
          random: _ControlledRandom(),
        );

        expect(next.board.rows, [
          [3, null, null, 1],
        ]);
      });

      test('rejects invalid tile levels', () {
        for (final level in [0, -1, 4]) {
          expect(
            () => GameState(
              GameBoard([
                [level, null, null, null],
              ]),
              configuration: configuration,
            ),
            throwsArgumentError,
          );
        }
      });

      test('rejects configuration dimensions that do not match', () {
        expect(
          () => GameState(
            GameBoard([
              [1, null],
              [null, null],
            ]),
            configuration: configuration,
          ),
          throwsArgumentError,
        );
      });
    });

    group('variable board dimensions', () {
      test('moves and spawns on a 5x5 board', () {
        final state = GameState(
          GameBoard([
            [1, null, 1, null, 2],
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
          [2, 2, null, null, null],
          [null, null, null, null, null],
          [null, null, null, null, null],
          [null, null, null, null, null],
          [null, null, null, null, 1],
        ]);
      });

      test('moves vertically on a rectangular 4x6 board', () {
        final state = GameState(
          GameBoard([
            [1, null, null, null, null, null],
            [1, null, null, null, null, null],
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
          [2, null, null, null, null, 1],
        ]);
      });
    });

    group('spawning', () {
      for (var position = 0; position < 14; position++) {
        test('selects empty cell $position in row order', () {
          final state = GameState(
            GameBoard(_rowsWithLine([null, 1, 2, null], MoveDirection.left)),
          );

          final random = _ControlledRandom(position: position);

          final expectedRows = _rowsWithLine([
            1,
            2,
            null,
            null,
          ], MoveDirection.left);

          final cell = position + 2;

          expectedRows[cell ~/ _classicBoardSize][cell % _classicBoardSize] = 1;

          final next = state.move(MoveDirection.left, random: random);

          expect(next.board.rows, expectedRows);
          expect(random.calls, ['nextInt(14)', 'nextDouble']);
        });
      }

      for (final (roll, level) in [
        (0.0, 1),
        (0.899999999, 1),
        (0.9, 2),
        (0.999999999, 2),
      ]) {
        test('spawns level $level for a roll of $roll', () {
          final state = GameState(
            GameBoard(_rowsWithLine([null, 1, 2, null], MoveDirection.left)),
          );

          final expectedRows = _rowsWithLine([
            1,
            2,
            null,
            null,
          ], MoveDirection.left);

          expectedRows[3][3] = level;

          final next = state.move(
            MoveDirection.left,
            random: _ControlledRandom(tileRoll: roll),
          );

          expect(next.board.rows, expectedRows);
        });
      }

      test('uses the only cell freed by a merge on a full board', () {
        final state = GameState(
          GameBoard([
            [1, 1, 3, 4],
            [2, 3, 4, 5],
            [3, 4, 5, 6],
            [4, 5, 6, 7],
          ]),
        );

        final random = _ControlledRandom(tileRoll: 0.9);

        final next = state.move(MoveDirection.left, random: random);

        expect(next.board.rows, [
          [2, 3, 4, 2],
          [2, 3, 4, 5],
          [3, 4, 5, 6],
          [4, 5, 6, 7],
        ]);

        expect(random.calls, ['nextInt(1)', 'nextDouble']);
      });
    });

    test('starts with the configured number of tiles', () {
      final configuration = GameConfiguration(rowCount: 2, columnCount: 2);

      final random = _ControlledRandom();

      final state = GameState.start(
        configuration: configuration,
        random: random,
      );

      expect(state.board.rows, [
        [null, null],
        [1, 1],
      ]);

      expect(state.configuration, same(configuration));

      expect(random.calls, [
        'nextInt(4)',
        'nextDouble',
        'nextInt(3)',
        'nextDouble',
      ]);
    });

    test('replays moves with equivalent random sources', () {
      final initial = GameState(
        GameBoard(_rowsWithLine([1, null, 1, 2], MoveDirection.left)),
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
      expect(initial.board.rows.first, [1, null, 1, 2]);
    });

    test('retained states stay unchanged through later moves', () {
      var state = GameState(
        GameBoard(_rowsWithLine([1, null, 1, 2], MoveDirection.left)),
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
