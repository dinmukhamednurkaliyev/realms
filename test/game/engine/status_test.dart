import 'dart:math';

import 'package:realms/game/engine/engine.dart';
import 'package:test/test.dart';

void main() {
  group('Game status', () {
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
        final moveResult = state.moveWithResult(
          direction: MoveDirection.left,
          random: Random(42),
        );

        expect(state.status, GameStatus.won);
        expect(moveResult.changed, isTrue);
        expect(moveResult.scoreGained, 90);
        expect(moveResult.spawnedTile, isNotNull);
        expect(moveResult.state.configuration, same(configuration));
        expect(moveResult.state.status, GameStatus.won);
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

      expect(state.status, GameStatus.inProgress);
      expect(state.isGameOver, isFalse);
      expect(state.hasAvailableMoves, isTrue);
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

      expect(state.status, GameStatus.lost);
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

      expect(state.hasAvailableMoves, isTrue);
      expect(state.status, GameStatus.won);
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

      expect(state.hasAvailableMoves, isFalse);
      expect(state.status, GameStatus.won);
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

      expect(state.status, GameStatus.lost);
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
      final moveResult = state.moveWithResult(
        direction: MoveDirection.left,
        random: Random(42),
      );

      expect(state.status, GameStatus.inProgress);
      expect(moveResult.state.status, GameStatus.won);
      expect(moveResult.scoreGained, 40);
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

      expect(state.status, GameStatus.won);
      expect(state.score, 800);
    });

    test('reports an empty restored board as lost', () {
      final state = GameState(
        board: GameBoard.empty(rowCount: 1, columnCount: 2),
      );

      expect(state.status, GameStatus.lost);
      expect(state.isGameOver, isTrue);
    });
  });
}
