import 'dart:math';

import 'package:realms/game/engine.dart';
import 'package:test/test.dart';

void main() {
  group('Tile level objectives', () {
    test('rejects a non-positive target level', () {
      expect(
        () => ReachTileLevelObjective(targetLevel: 0),
        throwsArgumentError,
      );
    });

    test('rejects a target above the configured maximum level', () {
      expect(
        () => GameConfiguration(
          maxTileLevel: 3,
          objective: ReachTileLevelObjective(targetLevel: 4),
        ),
        throwsArgumentError,
      );
    });

    test('is incomplete when no tile reaches the target', () {
      final state = GameState(
        board: GameBoard(
          rows: [
            [1, 2, null],
          ],
        ),
        configuration: GameConfiguration(
          rowCount: 1,
          columnCount: 3,
          objective: ReachTileLevelObjective(targetLevel: 3),
        ),
      );

      expect(state.hasCompletedObjective, isFalse);
    });

    test('becomes complete after a merge reaches the target', () {
      final configuration = GameConfiguration(
        rowCount: 1,
        columnCount: 3,
        objective: ReachTileLevelObjective(targetLevel: 2),
      );
      final state = GameState(
        board: GameBoard(
          rows: [
            [1, 1, null],
          ],
        ),
        configuration: configuration,
      );

      final nextState = state.move(
        direction: MoveDirection.left,
        random: Random(42),
      );

      expect(state.hasCompletedObjective, isFalse);
      expect(nextState.hasCompletedObjective, isTrue);
      expect(nextState.score, 40);
    });

    test('recognizes an already completed restored board', () {
      final state = GameState(
        board: GameBoard(
          rows: [
            [4, null],
          ],
        ),
        configuration: GameConfiguration(
          rowCount: 1,
          columnCount: 2,
          objective: ReachTileLevelObjective(targetLevel: 3),
        ),
        score: 300,
      );

      expect(state.hasCompletedObjective, isTrue);
      expect(state.score, 300);
    });

    test('can be completed by an initial spawn', () {
      final configuration = GameConfiguration(
        rowCount: 1,
        columnCount: 2,
        maxTileLevel: 2,
        initialTileCount: 1,
        spawnWeights: {2: 1},
        objective: ReachTileLevelObjective(targetLevel: 2),
      );

      final state = GameState.start(
        configuration: configuration,
        random: Random(42),
      );

      expect(state.hasCompletedObjective, isTrue);
    });
  });

  group('Objective completion', () {
    test('Endless games have no completed objective', () {
      final state = GameState(
        board: GameBoard(
          rows: [
            [2, null],
          ],
        ),
      );

      expect(state.configuration.objective, isNull);
      expect(state.hasCompletedObjective, isFalse);
    });

    test('supports an objective based on accumulated score', () {
      final configuration = GameConfiguration(
        rowCount: 1,
        columnCount: 2,
        objective: const _ScoreThresholdObjective(minimumScore: 100),
      );
      final state = GameState(
        board: GameBoard(
          rows: [
            [1, null],
          ],
        ),
        configuration: configuration,
        score: 99,
      );
      final completedState = GameState(
        board: state.board,
        configuration: configuration,
        score: 100,
      );

      expect(state.hasCompletedObjective, isFalse);
      expect(completedState.hasCompletedObjective, isTrue);
    });

    test('recognizes a completed objective when the board is blocked', () {
      final configuration = GameConfiguration(
        rowCount: 1,
        columnCount: 2,
        maxTileLevel: 2,
        spawnWeights: {1: 1},
        objective: ReachTileLevelObjective(targetLevel: 2),
      );
      final state = GameState(
        board: GameBoard(
          rows: [
            [2, 2],
          ],
        ),
        configuration: configuration,
      );

      expect(state.hasCompletedObjective, isTrue);
      expect(state.hasAvailableMoves, isFalse);
      expect(state.isGameOver, isTrue);
    });
  });
}

final class _ScoreThresholdObjective implements GameObjective {
  const new({required this.minimumScore});

  final int minimumScore;

  @override
  bool isCompleted({required GameBoard board, required int score}) {
    return score >= minimumScore;
  }
}
