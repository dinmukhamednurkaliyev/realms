import 'dart:math';

import 'package:engine/engine.dart';
import 'package:test/test.dart';

const _classicBoardSize = 4;

void main() {
  group('GameState', () {
    final configuration = GameConfiguration(
      rowCount: 1,
      maxTileLevel: 3,
      spawnWeights: {1: 1},
    );

    test('rejects invalid tile levels', () {
      for (final level in [0, -1, 4]) {
        expect(
          () => GameState(
            board: GameBoard(
              rows: [
                [level, null, null, null],
              ],
            ),
            configuration: configuration,
          ),
          throwsArgumentError,
        );
      }
    });

    test('rejects configuration dimensions that do not match', () {
      expect(
        () => GameState(
          board: GameBoard(
            rows: [
              [1, null],
              [null, null],
            ],
          ),
          configuration: configuration,
        ),
        throwsArgumentError,
      );
    });

    test('infers a valid configuration for a single cell', () {
      final board = GameBoard(
        rows: [
          [1],
        ],
      );
      final state = GameState(board: board);

      expect(state.board, same(board));
      expect(state.configuration.rowCount, 1);
      expect(state.configuration.columnCount, 1);
      expect(state.configuration.initialTileCount, 1);
    });
  });

  group('GameState.start', () {
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

    for (final (rowCount, columnCount) in [(1, 1), (2, 3)]) {
      test('can fill a ${rowCount}x$columnCount board at startup', () {
        final cellCount = rowCount * columnCount;
        final configuration = GameConfiguration(
          rowCount: rowCount,
          columnCount: columnCount,
          initialTileCount: cellCount,
          maxTileLevel: 3,
          spawnWeights: {3: 1},
        );
        final random = _ControlledRandom(levelRoll: 0.999999999);

        final state = GameState.start(
          configuration: configuration,
          random: random,
        );

        expect(
          state.board.rows,
          List.generate(rowCount, (_) => List.filled(columnCount, 3)),
        );
        expect(state.configuration, same(configuration));
        expect(random.calls, [
          for (var remaining = cellCount; remaining > 0; remaining--) ...[
            'nextInt($remaining)',
            'nextDouble',
          ],
        ]);
      });
    }
  });

  group('GameState.move', () {
    const lineCases = <({String name, List<int?> input, List<int?> output})>[
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
            final originalRows = _rowsWithLine(
              tiles: testCase.input,
              direction: direction,
            );

            final state = GameState(board: GameBoard(rows: originalRows));

            final expectedRows = _rowsWithLine(
              tiles: testCase.output,
              direction: direction,
            );

            expectedRows[3][3] = 1;

            final next = state.move(
              direction: direction,
              random: _ControlledRandom(),
            );

            expect(next.board.rows, expectedRows);
            expect(state.board.rows, originalRows);
            expect(next, isNot(same(state)));
          });
        }

        test('does not spawn when the board does not change', () {
          final state = GameState(
            board: GameBoard(
              rows: _rowsWithLine(tiles: [1, 2, 3, 4], direction: direction),
            ),
          );

          final random = _ControlledRandom();

          expect(state.move(direction: direction, random: random), same(state));

          expect(random.calls, isEmpty);
        });

        test('does not spawn on an empty board', () {
          final state = GameState(board: GameBoard(rows: _emptyRows()));
          final random = _ControlledRandom();

          expect(state.move(direction: direction, random: random), same(state));

          expect(random.calls, isEmpty);
        });

        test('does not move a blocked full board', () {
          final state = GameState(
            board: GameBoard(
              rows: [
                [1, 2, 1, 2],
                [2, 1, 2, 1],
                [1, 2, 1, 2],
                [2, 1, 2, 1],
              ],
            ),
          );

          final random = _ControlledRandom();

          expect(state.move(direction: direction, random: random), same(state));

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
          board: GameBoard(
            rows: [
              [3, 3, null, null],
            ],
          ),
          configuration: configuration,
        );

        final random = _ControlledRandom();

        expect(
          state.move(direction: MoveDirection.left, random: random),
          same(state),
        );

        expect(random.calls, isEmpty);
      });

      test('merges tiles below the maximum level', () {
        final state = GameState(
          board: GameBoard(
            rows: [
              [2, 2, null, null],
            ],
          ),
          configuration: configuration,
        );

        final next = state.move(
          direction: MoveDirection.left,
          random: _ControlledRandom(),
        );

        expect(next.board.rows, [
          [3, null, null, 1],
        ]);
      });
    });

    group('variable board dimensions', () {
      const rectangularResults = <MoveDirection, List<List<int?>>>{
        MoveDirection.left: [
          [2, null, null],
          [1, 2, 1],
        ],
        MoveDirection.right: [
          [null, null, 2],
          [1, 1, 2],
        ],
        MoveDirection.up: [
          [2, 2, 1],
          [null, null, 1],
        ],
        MoveDirection.down: [
          [null, null, 1],
          [2, 2, 1],
        ],
      };

      for (final entry in rectangularResults.entries) {
        test('moves ${entry.key.name} on an asymmetric rectangle', () {
          final state = GameState(
            board: GameBoard(
              rows: [
                [1, null, 1],
                [1, 2, null],
              ],
            ),
          );
          final random = _ControlledRandom();

          final next = state.move(direction: entry.key, random: random);

          expect(next.board.rows, entry.value);
          expect(next.configuration, same(state.configuration));
          expect(random.calls, ['nextInt(3)', 'nextDouble']);
        });
      }

      const singleLineCases = [
        (
          name: 'single row',
          rows: [
            [1, null, 1],
          ],
          results: {
            MoveDirection.left: [
              [2, null, 1],
            ],
            MoveDirection.right: [
              [null, 1, 2],
            ],
          },
        ),
        (
          name: 'single column',
          rows: [
            [1],
            [null],
            [1],
          ],
          results: {
            MoveDirection.up: [
              [2],
              [null],
              [1],
            ],
            MoveDirection.down: [
              [null],
              [1],
              [2],
            ],
          },
        ),
      ];

      for (final testCase in singleLineCases) {
        for (final direction in MoveDirection.values) {
          test('${testCase.name} handles ${direction.name}', () {
            final state = GameState(board: GameBoard(rows: testCase.rows));
            final random = _ControlledRandom();

            final next = state.move(direction: direction, random: random);
            final expectedRows = testCase.results[direction];

            if (expectedRows == null) {
              expect(next, same(state));
              expect(random.calls, isEmpty);
            } else {
              expect(next.board.rows, expectedRows);
              expect(random.calls, ['nextInt(2)', 'nextDouble']);
            }
          });
        }
      }

      test('does not move a single empty or occupied cell', () {
        for (final level in [null, 1]) {
          final state = GameState(
            board: GameBoard(
              rows: [
                [level],
              ],
            ),
          );
          final random = _ControlledRandom();

          for (final direction in MoveDirection.values) {
            expect(
              state.move(direction: direction, random: random),
              same(state),
            );
          }

          expect(random.calls, isEmpty);
        }
      });

      test('moves and spawns on a 5x5 board', () {
        final state = GameState(
          board: GameBoard(
            rows: [
              [1, null, 1, null, 2],
              [null, null, null, null, null],
              [null, null, null, null, null],
              [null, null, null, null, null],
              [null, null, null, null, null],
            ],
          ),
        );

        final next = state.move(
          direction: MoveDirection.left,
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
          board: GameBoard(
            rows: [
              [1, null, null, null, null, null],
              [1, null, null, null, null, null],
              [null, null, null, null, null, null],
              [null, null, null, null, null, null],
            ],
          ),
        );

        final next = state.move(
          direction: MoveDirection.down,
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
      for (final (emptyCellIndex, expectedRows) in const [
        (
          0,
          [
            [1, 2, 1],
            [3, null, null],
          ],
        ),
        (
          1,
          [
            [1, 2, null],
            [3, 1, null],
          ],
        ),
        (
          2,
          [
            [1, 2, null],
            [3, null, 1],
          ],
        ),
      ]) {
        test('selects sparse empty cell $emptyCellIndex in row order', () {
          final state = GameState(
            board: GameBoard(
              rows: [
                [null, 1, 2],
                [null, 3, null],
              ],
            ),
          );
          final random = _ControlledRandom(emptyCellIndex: emptyCellIndex);

          final next = state.move(
            direction: MoveDirection.left,
            random: random,
          );

          expect(next.board.rows, expectedRows);
          expect(random.calls, ['nextInt(3)', 'nextDouble']);
        });
      }

      for (final (roll, level) in [
        (0.0, 3),
        (0.249999999, 3),
        (0.25, 1),
        (0.749999999, 1),
        (0.75, 2),
        (0.999999999, 2),
      ]) {
        test('uses custom weight order for a roll of $roll', () {
          final state = GameState(
            board: GameBoard(
              rows: [
                [null, 1],
              ],
            ),
            configuration: GameConfiguration(
              rowCount: 1,
              columnCount: 2,
              initialTileCount: 1,
              maxTileLevel: 3,
              spawnWeights: {3: 1, 1: 2, 2: 1},
            ),
          );
          final random = _ControlledRandom(levelRoll: roll);

          final next = state.move(
            direction: MoveDirection.left,
            random: random,
          );

          expect(next.board.rows, [
            [1, level],
          ]);
          expect(random.calls, ['nextInt(1)', 'nextDouble']);
        });
      }

      for (var emptyCellIndex = 0; emptyCellIndex < 14; emptyCellIndex++) {
        test('selects empty cell $emptyCellIndex in row order', () {
          final state = GameState(
            board: GameBoard(
              rows: _rowsWithLine(
                tiles: [null, 1, 2, null],
                direction: MoveDirection.left,
              ),
            ),
          );

          final random = _ControlledRandom(emptyCellIndex: emptyCellIndex);

          final expectedRows = _rowsWithLine(
            tiles: [1, 2, null, null],
            direction: MoveDirection.left,
          );

          final cellIndex = emptyCellIndex + 2;
          final rowIndex = cellIndex ~/ _classicBoardSize;
          final columnIndex = cellIndex % _classicBoardSize;

          expectedRows[rowIndex][columnIndex] = 1;

          final next = state.move(
            direction: MoveDirection.left,
            random: random,
          );

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
            board: GameBoard(
              rows: _rowsWithLine(
                tiles: [null, 1, 2, null],
                direction: MoveDirection.left,
              ),
            ),
          );

          final expectedRows = _rowsWithLine(
            tiles: [1, 2, null, null],
            direction: MoveDirection.left,
          );

          expectedRows[3][3] = level;

          final next = state.move(
            direction: MoveDirection.left,
            random: _ControlledRandom(levelRoll: roll),
          );

          expect(next.board.rows, expectedRows);
        });
      }

      test('uses the only cell freed by a merge on a full board', () {
        final state = GameState(
          board: GameBoard(
            rows: [
              [1, 1, 3, 4],
              [2, 3, 4, 5],
              [3, 4, 5, 6],
              [4, 5, 6, 7],
            ],
          ),
        );

        final random = _ControlledRandom(levelRoll: 0.9);

        final next = state.move(direction: MoveDirection.left, random: random);

        expect(next.board.rows, [
          [2, 3, 4, 2],
          [2, 3, 4, 5],
          [3, 4, 5, 6],
          [4, 5, 6, 7],
        ]);

        expect(random.calls, ['nextInt(1)', 'nextDouble']);
      });
    });

    test('preserves a known move and random draw sequence', () {
      final initial = GameState(
        board: GameBoard(
          rows: [
            [1, 1, 2],
            [null, null, null],
          ],
        ),
      );
      var state = initial;
      final random = _ControlledRandom(emptyCellIndex: 0, levelRoll: 0.9);
      const turns = [
        (
          direction: MoveDirection.left,
          rows: [
            [2, 2, 2],
            [null, null, null],
          ],
          emptyCellCount: 4,
        ),
        (
          direction: MoveDirection.up,
          rows: [
            [2, 2, 2],
            [null, null, null],
          ],
          emptyCellCount: null,
        ),
        (
          direction: MoveDirection.down,
          rows: [
            [2, null, null],
            [2, 2, 2],
          ],
          emptyCellCount: 3,
        ),
        (
          direction: MoveDirection.right,
          rows: [
            [2, null, 2],
            [null, 2, 3],
          ],
          emptyCellCount: 3,
        ),
        (
          direction: MoveDirection.up,
          rows: [
            [2, 2, 2],
            [2, null, 3],
          ],
          emptyCellCount: 2,
        ),
      ];

      for (final turn in turns) {
        final callCount = random.calls.length;
        final next = state.move(direction: turn.direction, random: random);

        expect(next.board.rows, turn.rows);
        expect(next.configuration, same(initial.configuration));
        if (turn.emptyCellCount == null) {
          expect(next, same(state));
          expect(random.calls.length, callCount);
        } else {
          expect(next, isNot(same(state)));
          expect(random.calls.skip(callCount), [
            'nextInt(${turn.emptyCellCount})',
            'nextDouble',
          ]);
        }

        state = next;
      }

      expect(initial.board.rows, [
        [1, 1, 2],
        [null, null, null],
      ]);
    });

    test('replays moves with equivalent random sources', () {
      final initial = GameState(
        board: GameBoard(
          rows: _rowsWithLine(
            tiles: [1, null, 1, 2],
            direction: MoveDirection.left,
          ),
        ),
      );

      var first = initial;
      var second = initial;

      final firstRandom = Random(42);
      final secondRandom = Random(42);

      for (var turn = 0; turn < 100; turn++) {
        final direction =
            MoveDirection.values[turn % MoveDirection.values.length];

        first = first.move(direction: direction, random: firstRandom);
        second = second.move(direction: direction, random: secondRandom);

        expect(first.board.rows, second.board.rows);
      }

      expect(firstRandom.nextDouble(), secondRandom.nextDouble());
      expect(initial.board.rows.first, [1, null, 1, 2]);
    });

    test('retained states stay unchanged through later moves', () {
      var state = GameState(
        board: GameBoard(
          rows: _rowsWithLine(
            tiles: [1, null, 1, 2],
            direction: MoveDirection.left,
          ),
        ),
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

        state = state.move(direction: direction, random: random);
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

List<List<int?>> _rowsWithLine({
  required List<int?> tiles,
  required MoveDirection direction,
}) {
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
  new({this.emptyCellIndex, this.levelRoll = 0});

  final int? emptyCellIndex;
  final double levelRoll;
  final calls = <String>[];

  @override
  int nextInt(int max) {
    calls.add('nextInt($max)');
    return emptyCellIndex ?? max - 1;
  }

  @override
  double nextDouble() {
    calls.add('nextDouble');
    return levelRoll;
  }

  @override
  bool nextBool() {
    throw UnsupportedError('Unexpected random boolean draw.');
  }
}
