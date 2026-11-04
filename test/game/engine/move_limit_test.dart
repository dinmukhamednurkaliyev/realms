import 'dart:math';

import 'package:realms/game/engine/engine.dart';
import 'package:test/test.dart';

void main() {
  group('Move limit configuration', () {
    test('has no move limit by default', () {
      final configuration = GameConfiguration();
      final state = GameState(
        board: GameBoard(
          rows: [
            [1, null],
          ],
        ),
      );

      expect(configuration.moveLimit, isNull);
      expect(state.movesRemaining, isNull);
      expect(state.movesMade, 0);
    });

    test('rejects non-positive move limits', () {
      expect(() => GameConfiguration(moveLimit: 0), throwsArgumentError);
      expect(() => GameConfiguration(moveLimit: -1), throwsArgumentError);
    });
  });

  group('Move counting', () {
    test('allows the last exactly representable move count', () {
      final state = GameState(
        board: GameBoard(
          rows: [
            [1, null],
          ],
        ),
        movesMade: 9007199254740990,
      );

      final nextState = state.move(
        direction: MoveDirection.right,
        random: Random(42),
      );

      expect(nextState.movesMade, 9007199254740991);
    });

    test('rejects move counts outside the exact integer range', () {
      final board = GameBoard(
        rows: [
          [1, null],
        ],
      );

      expect(
        () => GameState(board: board, movesMade: 9007199254740992),
        throwsArgumentError,
      );
    });

    test('does not overflow the move count or consume randomness', () {
      final state = GameState(
        board: GameBoard(
          rows: [
            [1, null],
          ],
        ),
        movesMade: 9007199254740991,
      );
      final random = Random(42);
      final expectedRandom = Random(42);

      expect(
        state.move(direction: MoveDirection.left, random: random),
        same(state),
      );
      expect(
        () => state.move(direction: MoveDirection.right, random: random),
        throwsStateError,
      );
      expect(state.movesMade, 9007199254740991);
      expect(random.nextDouble(), expectedRandom.nextDouble());
    });

    test('counts successful moves and updates remaining moves', () {
      final configuration = GameConfiguration(rowCount: 1, moveLimit: 2);
      final state = GameState(
        board: GameBoard(
          rows: [
            [null, 1, null, null],
          ],
        ),
        configuration: configuration,
      );

      final nextState = state.move(
        direction: MoveDirection.left,
        random: Random(42),
      );

      expect(state.movesMade, 0);
      expect(state.movesRemaining, 2);
      expect(nextState.movesMade, 1);
      expect(nextState.movesRemaining, 1);
      expect(nextState.configuration, same(configuration));
    });

    test('does not count a move that leaves the board unchanged', () {
      final state = GameState(
        board: GameBoard(
          rows: [
            [1, 2, null, null],
          ],
        ),
        configuration: GameConfiguration(rowCount: 1, moveLimit: 2),
      );
      final random = Random(42);
      final expectedRandom = Random(42);

      final result = state.moveWithResult(
        direction: MoveDirection.left,
        random: random,
      );

      expect(result.changed, isFalse);
      expect(result.state, same(state));
      expect(result.state.movesMade, 0);
      expect(result.state.movesRemaining, 2);
      expect(random.nextInt(100), expectedRandom.nextInt(100));
    });

    test('restores the move count and rejects invalid snapshots', () {
      final configuration = GameConfiguration(
        rowCount: 1,
        columnCount: 2,
        moveLimit: 3,
      );
      final board = GameBoard(
        rows: [
          [1, null],
        ],
      );
      final restored = GameState(
        board: board,
        configuration: configuration,
        movesMade: 2,
        score: 100,
      );

      expect(restored.movesMade, 2);
      expect(restored.movesRemaining, 1);
      expect(restored.score, 100);
      expect(
        () => GameState(
          board: board,
          configuration: configuration,
          movesMade: -1,
        ),
        throwsArgumentError,
      );
      expect(
        () =>
            GameState(board: board, configuration: configuration, movesMade: 4),
        throwsArgumentError,
      );
    });
  });

  group('Move limit outcomes', () {
    test('loses after the last move even if the board can still slide', () {
      final configuration = GameConfiguration(rowCount: 1, moveLimit: 1);
      final state = GameState(
        board: GameBoard(
          rows: [
            [null, 1, null, null],
          ],
        ),
        configuration: configuration,
      );

      final nextState = state.move(
        direction: MoveDirection.left,
        random: Random(42),
      );

      expect(state.status, GameStatus.inProgress);
      expect(nextState.movesMade, 1);
      expect(nextState.movesRemaining, 0);
      expect(nextState.hasAvailableMoves, isFalse);
      expect(nextState.status, GameStatus.lost);
      expect(nextState.isGameOver, isTrue);
    });

    test('does not move or draw randomness after exhausting the limit', () {
      final configuration = GameConfiguration(rowCount: 1, moveLimit: 1);
      final state = GameState(
        board: GameBoard(
          rows: [
            [1, null, null, null],
          ],
        ),
        configuration: configuration,
        movesMade: 1,
      );
      final random = Random(42);
      final expectedRandom = Random(42);

      final result = state.moveWithResult(
        direction: MoveDirection.right,
        random: random,
      );

      expect(result.state, same(state));
      expect(result.changed, isFalse);
      expect(result.movements, isEmpty);
      expect(result.merges, isEmpty);
      expect(result.spawnedTile, isNull);
      expect(state.board.rows, [
        [1, null, null, null],
      ]);
      expect(random.nextInt(100), expectedRandom.nextInt(100));
    });

    test('awards victory when the final permitted move reaches the goal', () {
      final configuration = GameConfiguration(
        rowCount: 1,
        moveLimit: 1,
        objective: ReachTileLevelObjective(targetLevel: 2),
      );
      final state = GameState(
        board: GameBoard(
          rows: [
            [1, 1, null, null],
          ],
        ),
        configuration: configuration,
      );

      final result = state.moveWithResult(
        direction: MoveDirection.left,
        random: Random(42),
      );

      expect(result.changed, isTrue);
      expect(result.scoreGained, 40);
      expect(result.state.movesRemaining, 0);
      expect(result.state.hasCompletedObjective, isTrue);
      expect(result.state.status, GameStatus.won);
      expect(result.state.isGameOver, isTrue);
    });
  });
}
