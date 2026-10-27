import 'package:engine/engine.dart';
import 'package:test/test.dart';

void main() {
  group('GameState game status', () {
    test('ends when a full board has no moves or merges', () {
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

    test('continues when adjacent tiles on a full board can merge', () {
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

    test('continues when tiles can slide without merging', () {
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

    test('checking game status does not change the state', () {
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
