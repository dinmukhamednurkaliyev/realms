import 'dart:math';

import 'package:engine/engine.dart';
import 'package:test/test.dart';

void main() {
  group('Move availability', () {
    for (final (rowCount, columnCount) in [(1, 1), (1, 3), (3, 1), (2, 3)]) {
      test(
        'agrees with moves for every small ${rowCount}x$columnCount board',
        () {
          const levels = <int?>[null, 1, 2];
          final configuration = GameConfiguration(
            rowCount: rowCount,
            columnCount: columnCount,
            initialTileCount: 1,
            maxTileLevel: 2,
          );
          final boardCount = pow(levels.length, rowCount * columnCount).toInt();

          for (var boardIndex = 0; boardIndex < boardCount; boardIndex++) {
            var remaining = boardIndex;
            final rows = List.generate(
              rowCount,
              (_) => List.generate(columnCount, (_) {
                final level = levels[remaining % levels.length];
                remaining ~/= levels.length;
                return level;
              }),
            );
            final state = GameState(
              board: GameBoard(rows: rows),
              configuration: configuration,
            );
            final results = [
              for (final direction in MoveDirection.values)
                state.moveWithResult(direction: direction, random: Random(42)),
            ];
            final hasChangedMove = results.any((result) => result.changed);

            expect(state.canMove, hasChangedMove, reason: '$rows');
            expect(state.isGameOver, !hasChangedMove, reason: '$rows');
          }
        },
      );
    }

    test('has no available moves on a full blocked board', () {
      final state = GameState(
        board: GameBoard(
          rows: [
            [1, 2],
            [2, 1],
          ],
        ),
      );

      expect(state.canMove, isFalse);
      expect(state.isGameOver, isTrue);
    });

    test('allows merges between adjacent tiles on a full board', () {
      final state = GameState(
        board: GameBoard(
          rows: [
            [1, 1],
            [2, 3],
          ],
        ),
      );

      expect(state.canMove, isTrue);
      expect(state.isGameOver, isFalse);
    });

    test('allows slides without merging', () {
      final state = GameState(
        board: GameBoard(
          rows: [
            [1, null],
            [2, 3],
          ],
        ),
      );

      expect(state.canMove, isTrue);
      expect(state.isGameOver, isFalse);
    });

    test('does not mistake an entirely empty board for a playable board', () {
      final state = GameState(
        board: GameBoard.empty(rowCount: 2, columnCount: 3),
      );

      expect(state.canMove, isFalse);
      expect(state.isGameOver, isTrue);
    });

    test('handles a single-cell board', () {
      for (final level in <int?>[null, 1]) {
        final state = GameState(
          board: GameBoard(
            rows: [
              [level],
            ],
          ),
        );

        expect(state.canMove, isFalse);
        expect(state.isGameOver, isTrue);
      }
    });

    test('cannot merge two tiles at the maximum evolution level', () {
      final configuration = GameConfiguration(
        rowCount: 1,
        columnCount: 2,
        maxTileLevel: 3,
        spawnWeights: {1: 1},
      );

      final state = GameState(
        board: GameBoard(
          rows: [
            [3, 3],
          ],
        ),
        configuration: configuration,
      );

      expect(state.canMove, isFalse);
      expect(state.isGameOver, isTrue);
    });

    test('can merge equal tiles below the maximum evolution level', () {
      final configuration = GameConfiguration(
        rowCount: 1,
        columnCount: 2,
        maxTileLevel: 3,
        spawnWeights: {1: 1},
      );

      final state = GameState(
        board: GameBoard(
          rows: [
            [2, 2],
          ],
        ),
        configuration: configuration,
      );

      expect(state.canMove, isTrue);
      expect(state.isGameOver, isFalse);
    });

    test('detects vertical merges on a rectangular board', () {
      final state = GameState(
        board: GameBoard(
          rows: [
            [1, 2],
            [1, 3],
            [4, 5],
          ],
        ),
      );

      expect(state.canMove, isTrue);
      expect(state.isGameOver, isFalse);
    });

    test('checking move availability does not change the state', () {
      final board = GameBoard(
        rows: [
          [1, null],
          [2, 3],
        ],
      );

      final state = GameState(board: board, score: 150);

      expect(state.canMove, isTrue);
      expect(state.isGameOver, isFalse);
      expect(state.board, same(board));

      expect(state.board.rows, [
        [1, null],
        [2, 3],
      ]);

      expect(state.score, 150);
    });
  });
}
