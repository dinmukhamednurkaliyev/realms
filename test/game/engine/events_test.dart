import 'dart:math';

import 'package:realms/game/game.dart' as game;
import 'package:test/test.dart';

void main() {
  group('Events', () {
    test('reports a changed move when tiles slide without merging', () {
      final state = game.State(
        board: game.Board(
          rows: [
            [null, 1, 2],
          ],
        ),
        score: 100,
      );
      final moveResult = state.moveWithResult(
        direction: game.MoveDirection.left,
        random: Random(42),
      );

      expect(moveResult.changed, isTrue);
      expect(moveResult.movements, hasLength(2));
      expect(moveResult.merges, isEmpty);
      expect(moveResult.scoreGained, 0);
      expect(moveResult.state.score, 100);
      expect(moveResult.state, isNot(same(state)));
      expect(moveResult.spawnedTile, isNotNull);
    });

    const rectangularMoveCases = [
      (
        direction: game.MoveDirection.left,
        movements: [
          (
            from: (rowIndex: 0, columnIndex: 2),
            to: (rowIndex: 0, columnIndex: 0),
            level: 1,
          ),
        ],
        firstSource: (rowIndex: 0, columnIndex: 0),
        secondSource: (rowIndex: 0, columnIndex: 2),
      ),
      (
        direction: game.MoveDirection.right,
        movements: [
          (
            from: (rowIndex: 0, columnIndex: 0),
            to: (rowIndex: 0, columnIndex: 2),
            level: 1,
          ),
          (
            from: (rowIndex: 1, columnIndex: 1),
            to: (rowIndex: 1, columnIndex: 2),
            level: 2,
          ),
          (
            from: (rowIndex: 1, columnIndex: 0),
            to: (rowIndex: 1, columnIndex: 1),
            level: 1,
          ),
        ],
        firstSource: (rowIndex: 0, columnIndex: 2),
        secondSource: (rowIndex: 0, columnIndex: 0),
      ),
      (
        direction: game.MoveDirection.up,
        movements: [
          (
            from: (rowIndex: 1, columnIndex: 0),
            to: (rowIndex: 0, columnIndex: 0),
            level: 1,
          ),
          (
            from: (rowIndex: 1, columnIndex: 1),
            to: (rowIndex: 0, columnIndex: 1),
            level: 2,
          ),
        ],
        firstSource: (rowIndex: 0, columnIndex: 0),
        secondSource: (rowIndex: 1, columnIndex: 0),
      ),
      (
        direction: game.MoveDirection.down,
        movements: [
          (
            from: (rowIndex: 0, columnIndex: 0),
            to: (rowIndex: 1, columnIndex: 0),
            level: 1,
          ),
          (
            from: (rowIndex: 0, columnIndex: 2),
            to: (rowIndex: 1, columnIndex: 2),
            level: 1,
          ),
        ],
        firstSource: (rowIndex: 1, columnIndex: 0),
        secondSource: (rowIndex: 0, columnIndex: 0),
      ),
    ];

    for (final testCase in rectangularMoveCases) {
      test('orders rectangular ${testCase.direction.name} events', () {
        final state = game.State(
          board: game.Board(
            rows: [
              [1, null, 1],
              [1, 2, null],
            ],
          ),
        );
        final moveResult = state.moveWithResult(
          direction: testCase.direction,
          random: Random(42),
        );

        expect(
          moveResult.movements.map(
            (movement) =>
                (from: movement.from, to: movement.to, level: movement.level),
          ),
          testCase.movements,
        );
        final merge = moveResult.merges.single;
        expect(merge.firstSource, testCase.firstSource);
        expect(merge.secondSource, testCase.secondSource);
        expect(merge.destination, testCase.firstSource);
        expect(merge.level, 2);
        expect(moveResult.mergedLevels, [2]);
      });
    }

    test('orders merges by line and then destination edge', () {
      final state = game.State(
        board: game.Board(
          rows: [
            [1, 1, 2, 2],
            [3, 3, 1, 1],
          ],
        ),
      );
      final moveResult = state.moveWithResult(
        direction: game.MoveDirection.left,
        random: Random(42),
      );

      expect(moveResult.mergedLevels, [2, 3, 4, 2]);
      expect(moveResult.merges.map((merge) => merge.destination), [
        (rowIndex: 0, columnIndex: 0),
        (rowIndex: 0, columnIndex: 1),
        (rowIndex: 1, columnIndex: 0),
        (rowIndex: 1, columnIndex: 1),
      ]);
      expect(moveResult.scoreGained, 330);
    });

    test('protects event collections for changed and unchanged moves', () {
      for (final rows in <List<List<int?>>>[
        [
          [1, 1, null],
        ],
        [
          [1, 2, null],
        ],
      ]) {
        final moveResult = game.State(board: game.Board(rows: rows))
            .moveWithResult(
              direction: game.MoveDirection.left,
              random: Random(42),
            );

        expect(moveResult.movements.clear, throwsUnsupportedError);
        expect(moveResult.merges.clear, throwsUnsupportedError);
        expect(() => moveResult.mergedLevels.add(3), throwsUnsupportedError);
      }
    });

    test('tracks tile movements and merges to the left', () {
      final state = game.State(
        board: game.Board(
          rows: [
            [1, null, 1, 2],
          ],
        ),
      );

      final moveResult = state.moveWithResult(
        direction: game.MoveDirection.left,
        random: Random(42),
      );

      expect(moveResult.changed, isTrue);
      expect(moveResult.merges, hasLength(1));
      expect(moveResult.movements, hasLength(2));

      final merge = moveResult.merges.single;

      expect(merge.firstSource, (rowIndex: 0, columnIndex: 0));
      expect(merge.secondSource, (rowIndex: 0, columnIndex: 2));
      expect(merge.destination, (rowIndex: 0, columnIndex: 0));
      expect(merge.level, 2);

      expect(moveResult.movements[0].from, (rowIndex: 0, columnIndex: 2));
      expect(moveResult.movements[0].to, (rowIndex: 0, columnIndex: 0));
      expect(moveResult.movements[1].from, (rowIndex: 0, columnIndex: 3));
      expect(moveResult.movements[1].to, (rowIndex: 0, columnIndex: 1));

      expect(moveResult.scoreGained, 40);
      expect(moveResult.mergedLevels, [2]);
      expect(moveResult.spawnedTile, isNotNull);

      final spawnedTile = moveResult.spawnedTile!;

      expect(
        moveResult.state.board.tileAt(
          rowIndex: spawnedTile.position.rowIndex,
          columnIndex: spawnedTile.position.columnIndex,
        ),
        spawnedTile.level,
      );

      expect(state.score, 0);
      expect(moveResult.state.score, 40);
    });

    test('tracks merges when moving down', () {
      final state = game.State(
        board: game.Board(
          rows: [
            [1],
            [null],
            [1],
          ],
        ),
      );

      final moveResult = state.moveWithResult(
        direction: game.MoveDirection.down,
        random: Random(42),
      );

      final merge = moveResult.merges.single;

      expect(merge.firstSource, (rowIndex: 2, columnIndex: 0));
      expect(merge.secondSource, (rowIndex: 0, columnIndex: 0));
      expect(merge.destination, (rowIndex: 2, columnIndex: 0));
      expect(merge.level, 2);
      expect(moveResult.scoreGained, 40);
    });

    test('returns no events for an unchanged move', () {
      final state = game.State(
        board: game.Board(
          rows: [
            [1, 2, null, null],
          ],
        ),
      );

      final random = Random(42);
      final expectedRandom = Random(42);

      final moveResult = state.moveWithResult(
        direction: game.MoveDirection.left,
        random: random,
      );

      expect(moveResult.changed, isFalse);
      expect(moveResult.state, same(state));
      expect(moveResult.scoreGained, 0);
      expect(moveResult.movements, isEmpty);
      expect(moveResult.merges, isEmpty);
      expect(moveResult.mergedLevels, isEmpty);
      expect(moveResult.spawnedTile, isNull);

      // An unchanged move must not consume random values.
      expect(random.nextInt(1000), expectedRandom.nextInt(1000));
    });
  });
}
