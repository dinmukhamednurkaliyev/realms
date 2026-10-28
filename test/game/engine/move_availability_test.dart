import 'dart:math';

import 'package:realms/game/game.dart' as game;
import 'package:test/test.dart';

void main() {
  group('Move availability', () {
    for (final (rowCount, columnCount) in [(1, 1), (1, 3), (3, 1), (2, 3)]) {
      test(
        'agrees with moves for every small ${rowCount}x$columnCount board',
        () {
          const cellValues = <int?>[null, 1, 2];
          final configuration = game.Configuration(
            rowCount: rowCount,
            columnCount: columnCount,
            initialTileCount: 1,
            maxTileLevel: 2,
          );
          final boardCount = pow(
            cellValues.length,
            rowCount * columnCount,
          ).toInt();

          for (var boardIndex = 0; boardIndex < boardCount; boardIndex++) {
            // Each base-N digit selects one cell value, including empty.
            var encodedCells = boardIndex;
            final rows = List.generate(
              rowCount,
              (_) => List.generate(columnCount, (_) {
                final cellValue = cellValues[encodedCells % cellValues.length];
                encodedCells ~/= cellValues.length;
                return cellValue;
              }),
            );
            final state = game.State(
              board: game.Board(rows: rows),
              configuration: configuration,
            );
            final moveResults = [
              for (final direction in game.MoveDirection.values)
                state.moveWithResult(direction: direction, random: Random(42)),
            ];
            final anyMoveChangesBoard = moveResults.any(
              (moveResult) => moveResult.changed,
            );

            expect(
              state.hasAvailableMoves,
              anyMoveChangesBoard,
              reason: '$rows',
            );
            expect(state.isGameOver, !anyMoveChangesBoard, reason: '$rows');
          }
        },
      );
    }

    test('has no available moves on a full blocked board', () {
      final state = game.State(
        board: game.Board(
          rows: [
            [1, 2],
            [2, 1],
          ],
        ),
      );

      expect(state.hasAvailableMoves, isFalse);
      expect(state.isGameOver, isTrue);
    });

    test('allows merges between adjacent tiles on a full board', () {
      final state = game.State(
        board: game.Board(
          rows: [
            [1, 1],
            [2, 3],
          ],
        ),
      );

      expect(state.hasAvailableMoves, isTrue);
      expect(state.isGameOver, isFalse);
    });

    test('allows slides without merging', () {
      final state = game.State(
        board: game.Board(
          rows: [
            [1, null],
            [2, 3],
          ],
        ),
      );

      expect(state.hasAvailableMoves, isTrue);
      expect(state.isGameOver, isFalse);
    });

    test('does not mistake an entirely empty board for a playable board', () {
      final state = game.State(
        board: game.Board.empty(rowCount: 2, columnCount: 3),
      );

      expect(state.hasAvailableMoves, isFalse);
      expect(state.isGameOver, isTrue);
    });

    test('handles a single-cell board', () {
      for (final level in <int?>[null, 1]) {
        final state = game.State(
          board: game.Board(
            rows: [
              [level],
            ],
          ),
        );

        expect(state.hasAvailableMoves, isFalse);
        expect(state.isGameOver, isTrue);
      }
    });

    test('cannot merge two tiles at the maximum evolution level', () {
      final configuration = game.Configuration(
        rowCount: 1,
        columnCount: 2,
        maxTileLevel: 3,
        spawnWeights: {1: 1},
      );

      final state = game.State(
        board: game.Board(
          rows: [
            [3, 3],
          ],
        ),
        configuration: configuration,
      );

      expect(state.hasAvailableMoves, isFalse);
      expect(state.isGameOver, isTrue);
    });

    test('can merge equal tiles below the maximum evolution level', () {
      final configuration = game.Configuration(
        rowCount: 1,
        columnCount: 2,
        maxTileLevel: 3,
        spawnWeights: {1: 1},
      );

      final state = game.State(
        board: game.Board(
          rows: [
            [2, 2],
          ],
        ),
        configuration: configuration,
      );

      expect(state.hasAvailableMoves, isTrue);
      expect(state.isGameOver, isFalse);
    });

    test('detects vertical merges on a rectangular board', () {
      final state = game.State(
        board: game.Board(
          rows: [
            [1, 2],
            [1, 3],
            [4, 5],
          ],
        ),
      );

      expect(state.hasAvailableMoves, isTrue);
      expect(state.isGameOver, isFalse);
    });

    test('checking move availability does not change the state', () {
      final board = game.Board(
        rows: [
          [1, null],
          [2, 3],
        ],
      );

      final state = game.State(board: board, score: 150);

      expect(state.hasAvailableMoves, isTrue);
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
