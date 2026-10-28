import 'dart:math';

import 'package:realms/game/engine.dart';
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
  });
}
