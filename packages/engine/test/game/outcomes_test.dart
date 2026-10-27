import 'dart:math';

import 'package:engine/engine.dart';
import 'package:test/test.dart';

void main() {
  group('Outcomes', () {
    test(
      'allows continued moves after victory without changing old snapshots',
      () {
        final configuration = GameConfiguration(
          rowCount: 1,
          columnCount: 3,
          objective: ReachTileLevelObjective(targetLevel: 2),
        );
        final state = GameState(
          board: GameBoard(
            rows: [
              [2, 2, null],
            ],
          ),
          configuration: configuration,
        );
        final result = state.moveWithResult(
          direction: MoveDirection.left,
          random: Random(42),
        );

        expect(state.outcome, GameOutcome.won);
        expect(result.changed, isTrue);
        expect(result.scoreGained, 90);
        expect(result.spawnedTile, isNotNull);
        expect(result.state.configuration, same(configuration));
        expect(result.state.outcome, GameOutcome.won);
        expect(state.board.rows, [
          [2, 2, null],
        ]);
        expect(state.score, 0);
      },
    );

    test('keeps an Endless game in progress while moves remain', () {
      final state = GameState(
        board: GameBoard(
          rows: [
            [1, null],
            [2, 3],
          ],
        ),
      );

      expect(state.outcome, GameOutcome.inProgress);
      expect(state.isGameOver, isFalse);
      expect(state.canMove, isTrue);
    });

    test('ends an Endless game in defeat when no moves remain', () {
      final state = GameState(
        board: GameBoard(
          rows: [
            [1, 2],
            [2, 1],
          ],
        ),
      );

      expect(state.outcome, GameOutcome.lost);
      expect(state.isGameOver, isTrue);
    });

    test('reports objective completion as victory even if moves remain', () {
      final configuration = GameConfiguration(
        rowCount: 1,
        columnCount: 3,
        objective: ReachTileLevelObjective(targetLevel: 2),
      );
      final state = GameState(
        board: GameBoard(
          rows: [
            [2, null, 1],
          ],
        ),
        configuration: configuration,
      );

      expect(state.canMove, isTrue);
      expect(state.outcome, GameOutcome.won);
      expect(state.isGameOver, isTrue);
    });

    test('gives victory priority when the completed board is also blocked', () {
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

      expect(state.canMove, isFalse);
      expect(state.outcome, GameOutcome.won);
      expect(state.isGameOver, isTrue);
    });

    test('reports defeat when blocked below the target level', () {
      final state = GameState(
        board: GameBoard(
          rows: [
            [1, 2],
          ],
        ),
        configuration: GameConfiguration(
          rowCount: 1,
          columnCount: 2,
          objective: ReachTileLevelObjective(targetLevel: 3),
        ),
      );

      expect(state.outcome, GameOutcome.lost);
    });

    test('changes from in progress to victory after a merge', () {
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
      final result = state.moveWithResult(
        direction: MoveDirection.left,
        random: Random(42),
      );

      expect(state.outcome, GameOutcome.inProgress);
      expect(result.state.outcome, GameOutcome.won);
      expect(result.scoreGained, 40);
    });

    test('evaluates victory correctly when restoring a saved state', () {
      final configuration = GameConfiguration(
        rowCount: 1,
        columnCount: 2,
        objective: ReachTileLevelObjective(targetLevel: 4),
      );
      final state = GameState(
        board: GameBoard(
          rows: [
            [4, 4],
          ],
        ),
        score: 800,
        configuration: configuration,
      );

      expect(state.outcome, GameOutcome.won);
      expect(state.score, 800);
    });

    test('reports an empty restored board as lost', () {
      final state = GameState(
        board: GameBoard.empty(rowCount: 1, columnCount: 2),
      );

      expect(state.outcome, GameOutcome.lost);
      expect(state.isGameOver, isTrue);
    });
  });
}
