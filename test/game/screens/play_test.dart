import 'dart:math';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:realms/game/engine/engine.dart';
import 'package:realms/game/screens/play.dart';

void main() {
  group('Play session', () {
    late ProviderContainer container;
    late ProviderSubscription<GameState> subscription;

    setUp(() {
      container = ProviderContainer();
      subscription = container.listen(playSessionProvider, (previous, next) {});
    });

    tearDown(() {
      subscription.close();
      container.dispose();
    });

    test('starts a classic game with two tiles and zero score', () {
      final state = container.read(playSessionProvider);
      final occupiedCells = state.board.rows
          .expand((row) => row)
          .where((tile) => tile != null);

      expect(state.board.rowCount, 4);
      expect(state.board.columnCount, 4);
      expect(occupiedCells, hasLength(2));
      expect(state.score, 0);
      expect(state.movesMade, 0);
    });

    test('publishes an immutable snapshot after a successful move', () {
      final previousState = container.read(playSessionProvider);
      final direction = MoveDirection.values.firstWhere(
        (direction) =>
            previousState.move(direction: direction, random: Random(42)) !=
            previousState,
      );

      container.read(playSessionProvider.notifier).move(direction);

      final nextState = container.read(playSessionProvider);
      expect(nextState, isNot(same(previousState)));
      expect(nextState.movesMade, 1);
      expect(previousState.movesMade, 0);
    });

    test('starts a fresh session with the same configuration', () {
      final previousState = container.read(playSessionProvider);

      container.read(playSessionProvider.notifier).startNewGame();

      final nextState = container.read(playSessionProvider);
      expect(nextState, isNot(same(previousState)));
      expect(nextState.configuration, same(previousState.configuration));
      expect(nextState.score, 0);
      expect(nextState.movesMade, 0);
      expect(
        nextState.board.rows.expand((row) => row).where((tile) => tile != null),
        hasLength(2),
      );
    });
  });
}
