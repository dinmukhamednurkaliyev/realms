import 'dart:math';

import 'package:engine/engine.dart';
import 'package:engine/src/game/mechanics.dart' as mechanics;
import 'package:test/test.dart';

void main() {
  group('Mechanics', () {
    for (final maxTileLevel in [1, 2, 3]) {
      for (final (rowCount, columnCount) in [
        (1, 1),
        (1, 3),
        (3, 1),
        (2, 3),
        (3, 2),
      ]) {
        test('canMoveBoard agrees with moves on every '
            '${rowCount}x$columnCount board up to level $maxTileLevel', () {
          final levels = <int?>[
            null,
            for (var level = 1; level <= maxTileLevel; level++) level,
          ];
          final boardCount = pow(levels.length, rowCount * columnCount).toInt();

          for (var boardIndex = 0; boardIndex < boardCount; boardIndex++) {
            var remaining = boardIndex;
            final board = GameBoard(
              rows: List.generate(
                rowCount,
                (_) => List.generate(columnCount, (_) {
                  final level = levels[remaining % levels.length];
                  remaining ~/= levels.length;
                  return level;
                }),
              ),
            );
            var hasChangedMove = false;

            for (final direction in MoveDirection.values) {
              final result = mechanics.moveBoard(
                board: board,
                direction: direction,
                maxTileLevel: maxTileLevel,
              );
              hasChangedMove |= result.board != board;
            }

            expect(
              mechanics.canMoveBoard(board: board, maxTileLevel: maxTileLevel),
              hasChangedMove,
              reason: '${board.rows}',
            );
          }
        });
      }
    }

    test('returns an immutable movement result before spawning', () {
      final board = GameBoard(
        rows: [
          [1, null, 1, 2],
        ],
      );

      final result = mechanics.moveBoard(
        board: board,
        direction: MoveDirection.left,
        maxTileLevel: 3,
      );

      expect(result.board.rows, [
        [2, 2, null, null],
      ]);
      expect(result.movements, hasLength(2));
      expect(result.merges.single.level, 2);
      expect(result.movements.clear, throwsUnsupportedError);
      expect(result.merges.clear, throwsUnsupportedError);
      expect(board.rows, [
        [1, null, 1, 2],
      ]);
    });

    test('rejects spawning on a full board before consuming randomness', () {
      final board = GameBoard(
        rows: [
          [1, 2],
        ],
      );
      final random = Random(42);
      final expectedRandom = Random(42);

      expect(
        () => mechanics.spawnTile(
          board: board,
          random: random,
          spawnWeights: {1: 1},
        ),
        throwsStateError,
      );

      expect(random.nextDouble(), expectedRandom.nextDouble());
      expect(board.rows, [
        [1, 2],
      ]);
    });
  });
}
