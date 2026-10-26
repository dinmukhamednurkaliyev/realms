import 'dart:math';

import 'package:engine/engine.dart';
import 'package:test/test.dart';

void main() {
  group('GameMoveResult events', () {
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
      expect(result.spawnedTile, isNull);

      // An unchanged move must not consume random values.
      expect(random.nextInt(1000), expectedRandom.nextInt(1000));
    });
  });
}
