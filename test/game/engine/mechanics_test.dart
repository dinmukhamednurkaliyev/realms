import 'dart:math';

import 'package:realms/game/engine.dart';
import 'package:realms/game/engine/mechanics.dart' as mechanics;
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
        test('hasAvailableMoves agrees with moves on every '
            '${rowCount}x$columnCount board up to level $maxTileLevel', () {
          final cellValues = <int?>[
            null,
            for (var level = 1; level <= maxTileLevel; level++) level,
          ];
          final boardCount = pow(
            cellValues.length,
            rowCount * columnCount,
          ).toInt();

          for (var boardIndex = 0; boardIndex < boardCount; boardIndex++) {
            // Each base-N digit selects one cell value, including empty.
            var encodedCells = boardIndex;
            final board = GameBoard(
              rows: List.generate(
                rowCount,
                (_) => List.generate(columnCount, (_) {
                  final cellValue =
                      cellValues[encodedCells % cellValues.length];
                  encodedCells ~/= cellValues.length;
                  return cellValue;
                }),
              ),
            );
            var anyMoveChangesBoard = false;

            for (final direction in MoveDirection.values) {
              final movementResult = mechanics.moveBoard(
                board: board,
                direction: direction,
                maxTileLevel: maxTileLevel,
              );
              anyMoveChangesBoard |= movementResult.board != board;
            }

            expect(
              mechanics.hasAvailableMoves(
                board: board,
                maxTileLevel: maxTileLevel,
              ),
              anyMoveChangesBoard,
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

      final movementResult = mechanics.moveBoard(
        board: board,
        direction: MoveDirection.left,
        maxTileLevel: 3,
      );

      expect(movementResult.board.rows, [
        [2, 2, null, null],
      ]);
      expect(movementResult.movements, hasLength(2));
      expect(movementResult.merges.single.level, 2);
      expect(movementResult.movements.clear, throwsUnsupportedError);
      expect(movementResult.merges.clear, throwsUnsupportedError);
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
