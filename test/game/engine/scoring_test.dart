import 'dart:math';

import 'package:realms/game/engine/engine.dart';
import 'package:test/test.dart';

void main() {
  group('Scoring', () {
    test('starts with zero points', () {
      final state = GameState.start(
        configuration: GameConfiguration(),
        random: Random(42),
      );

      expect(state.score, 0);
    });

    test('awards points for every merge', () {
      final state = GameState(
        board: GameBoard(
          rows: [
            [1, 1, 2, 2],
            [3, 3, null, null],
          ],
        ),
      );

      final nextState = state.move(
        direction: MoveDirection.left,
        random: Random(42),
      );

      // Level 2: 40 points
      // Level 3: 90 points
      // Level 4: 160 points
      expect(nextState.score, 290);
      expect(state.score, 0);
    });

    test('supports a custom score multiplier', () {
      final configuration = GameConfiguration(
        rowCount: 1,
        mergeScoreMultiplier: 25,
      );

      final state = GameState(
        board: GameBoard(
          rows: [
            [1, 1, null, null],
          ],
        ),
        configuration: configuration,
      );

      final nextState = state.move(
        direction: MoveDirection.left,
        random: Random(42),
      );

      expect(nextState.score, 100);
    });

    test('preserves score when moving without merging', () {
      final state = GameState(
        board: GameBoard(
          rows: [
            [null, 1, 2, null],
          ],
        ),
        score: 500,
      );

      final nextState = state.move(
        direction: MoveDirection.left,
        random: Random(42),
      );

      expect(nextState.score, 500);
      expect(state.score, 500);
    });

    test('keeps the same state when movement is impossible', () {
      final state = GameState(
        board: GameBoard(
          rows: [
            [1, 2, null, null],
          ],
        ),
        score: 250,
      );

      final nextState = state.move(
        direction: MoveDirection.left,
        random: Random(42),
      );

      expect(nextState, same(state));
      expect(nextState.score, 250);
    });

    test('rejects negative scores', () {
      expect(
        () => GameState(
          board: GameBoard(
            rows: [
              [1, null],
            ],
          ),
          score: -1,
        ),
        throwsArgumentError,
      );
    });

    test('rejects restored scores outside the exact integer range', () {
      expect(
        () => GameState(
          board: GameBoard(
            rows: [
              [1, 1],
            ],
          ),
          score: 9007199254740992,
        ),
        throwsArgumentError,
      );
    });

    test('allows a move that reaches the maximum exact score', () {
      final state = GameState(
        board: GameBoard(
          rows: [
            [1, 1],
          ],
        ),
        score: 9007199254740991 - 40,
      );

      final move = state.moveWithResult(
        direction: MoveDirection.left,
        random: Random(42),
      );

      expect(move.scoreGained, 40);
      expect(move.state.score, 9007199254740991);
    });

    test('allows sliding at the maximum score when no points are gained', () {
      final state = GameState(
        board: GameBoard(
          rows: [
            [1, null],
          ],
        ),
        score: 9007199254740991,
      );

      final move = state.moveWithResult(
        direction: MoveDirection.right,
        random: Random(42),
      );

      expect(move.changed, isTrue);
      expect(move.scoreGained, 0);
      expect(move.state.score, state.score);
      expect(move.spawnedTile, isNotNull);
    });

    test('rejects unrepresentable scores before drawing randomness', () {
      for (final (rows, score, multiplier) in [
        (
          [
            [1, 1],
          ],
          9007199254740991 - 39,
          10,
        ),
        (
          [
            [1, 1, 1, 1],
          ],
          9007199254740991 - 40,
          10,
        ),
        (
          [
            [1, 1],
          ],
          0,
          4611686018427387904,
        ),
      ]) {
        final state = GameState(
          board: GameBoard(rows: rows),
          score: score,
          configuration: GameConfiguration(
            rowCount: 1,
            columnCount: rows.single.length,
            mergeScoreMultiplier: multiplier,
          ),
        );
        final random = Random(42);
        final expectedRandom = Random(42);

        expect(
          () => state.moveWithResult(
            direction: MoveDirection.left,
            random: random,
          ),
          throwsStateError,
        );
        expect(state.board.rows, rows);
        expect(state.score, score);
        expect(state.movesMade, 0);
        expect(random.nextDouble(), expectedRandom.nextDouble());
      }
    });
  });
}
