import 'dart:math';

import 'package:engine/engine.dart';
import 'package:test/test.dart';

void main() {
  group('Events', () {
    test('reports a changed move when tiles slide without merging', () {
      final state = GameState(
        board: GameBoard(
          rows: [
            [null, 1, 2],
          ],
        ),
        score: 100,
      );
      final result = state.moveWithResult(
        direction: MoveDirection.left,
        random: Random(42),
      );

      expect(result.changed, isTrue);
      expect(result.movements, hasLength(2));
      expect(result.merges, isEmpty);
      expect(result.scoreGained, 0);
      expect(result.state.score, 100);
      expect(result.state, isNot(same(state)));
      expect(result.spawnedTile, isNotNull);
    });

    const rectangularCases = [
      (
        direction: MoveDirection.left,
        movements: [
          (
            from: (rowIndex: 0, columnIndex: 2),
            to: (rowIndex: 0, columnIndex: 0),
            level: 1,
          ),
        ],
        first: (rowIndex: 0, columnIndex: 0),
        second: (rowIndex: 0, columnIndex: 2),
      ),
      (
        direction: MoveDirection.right,
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
        first: (rowIndex: 0, columnIndex: 2),
        second: (rowIndex: 0, columnIndex: 0),
      ),
      (
        direction: MoveDirection.up,
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
        first: (rowIndex: 0, columnIndex: 0),
        second: (rowIndex: 1, columnIndex: 0),
      ),
      (
        direction: MoveDirection.down,
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
        first: (rowIndex: 1, columnIndex: 0),
        second: (rowIndex: 0, columnIndex: 0),
      ),
    ];

    for (final testCase in rectangularCases) {
      test('orders rectangular ${testCase.direction.name} events', () {
        final state = GameState(
          board: GameBoard(
            rows: [
              [1, null, 1],
              [1, 2, null],
            ],
          ),
        );
        final result = state.moveWithResult(
          direction: testCase.direction,
          random: Random(42),
        );

        expect(
          result.movements.map(
            (movement) =>
                (from: movement.from, to: movement.to, level: movement.level),
          ),
          testCase.movements,
        );
        final merge = result.merges.single;
        expect(merge.first, testCase.first);
        expect(merge.second, testCase.second);
        expect(merge.destination, testCase.first);
        expect(merge.level, 2);
        expect(result.mergedLevels, [2]);
      });
    }

    test('orders merges by line and then destination edge', () {
      final state = GameState(
        board: GameBoard(
          rows: [
            [1, 1, 2, 2],
            [3, 3, 1, 1],
          ],
        ),
      );
      final result = state.moveWithResult(
        direction: MoveDirection.left,
        random: Random(42),
      );

      expect(result.mergedLevels, [2, 3, 4, 2]);
      expect(result.merges.map((merge) => merge.destination), [
        (rowIndex: 0, columnIndex: 0),
        (rowIndex: 0, columnIndex: 1),
        (rowIndex: 1, columnIndex: 0),
        (rowIndex: 1, columnIndex: 1),
      ]);
      expect(result.scoreGained, 330);
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
        final result = GameState(board: GameBoard(rows: rows))
            .moveWithResult(direction: MoveDirection.left, random: Random(42));

        expect(result.movements.clear, throwsUnsupportedError);
        expect(result.merges.clear, throwsUnsupportedError);
        expect(() => result.mergedLevels.add(3), throwsUnsupportedError);
      }
    });

    test('tracks tile movements and merges to the left', () {
      final state = GameState(
        board: GameBoard(
          rows: [
            [1, null, 1, 2],
          ],
        ),
      );

      final result = state.moveWithResult(
        direction: MoveDirection.left,
        random: Random(42),
      );

      expect(result.changed, isTrue);
      expect(result.merges, hasLength(1));
      expect(result.movements, hasLength(2));

      final merge = result.merges.single;

      expect(merge.first, (rowIndex: 0, columnIndex: 0));

      expect(merge.second, (rowIndex: 0, columnIndex: 2));

      expect(merge.destination, (rowIndex: 0, columnIndex: 0));

      expect(merge.level, 2);

      expect(result.movements[0].from, (rowIndex: 0, columnIndex: 2));

      expect(result.movements[0].to, (rowIndex: 0, columnIndex: 0));

      expect(result.movements[1].from, (rowIndex: 0, columnIndex: 3));

      expect(result.movements[1].to, (rowIndex: 0, columnIndex: 1));

      expect(result.scoreGained, 40);
      expect(result.mergedLevels, [2]);
      expect(result.spawnedTile, isNotNull);

      final spawnedTile = result.spawnedTile!;

      expect(
        result.state.board.tileAt(
          rowIndex: spawnedTile.position.rowIndex,
          columnIndex: spawnedTile.position.columnIndex,
        ),
        spawnedTile.level,
      );

      expect(state.score, 0);
      expect(result.state.score, 40);
    });

    test('tracks merges when moving down', () {
      final state = GameState(
        board: GameBoard(
          rows: [
            [1],
            [null],
            [1],
          ],
        ),
      );

      final result = state.moveWithResult(
        direction: MoveDirection.down,
        random: Random(42),
      );

      final merge = result.merges.single;

      expect(merge.first, (rowIndex: 2, columnIndex: 0));

      expect(merge.second, (rowIndex: 0, columnIndex: 0));

      expect(merge.destination, (rowIndex: 2, columnIndex: 0));

      expect(merge.level, 2);
      expect(result.scoreGained, 40);
    });

    test('returns no events for an unchanged move', () {
      final state = GameState(
        board: GameBoard(
          rows: [
            [1, 2, null, null],
          ],
        ),
      );

      final random = Random(42);
      final expectedRandom = Random(42);

      final result = state.moveWithResult(
        direction: MoveDirection.left,
        random: random,
      );

      expect(result.changed, isFalse);
      expect(result.state, same(state));
      expect(result.scoreGained, 0);
      expect(result.movements, isEmpty);
      expect(result.merges, isEmpty);
      expect(result.mergedLevels, isEmpty);
      expect(result.spawnedTile, isNull);

      // An unchanged move must not consume random values.
      expect(random.nextInt(1000), expectedRandom.nextInt(1000));
    });
  });
}
