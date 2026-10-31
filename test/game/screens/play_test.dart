import 'dart:async';
import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:realms/game/engine/engine.dart';
import 'package:realms/game/screens/play.dart';

void main() {
  group('Play controller lifecycle', () {
    test('blocks moves until tutorial loading completes', () async {
      final store = _DeferredTutorialStore();
      final controller = PlayController(
        random: Random(42),
        tutorialStore: store,
      );
      addTearDown(controller.dispose);
      final initial = controller.state;
      controller.move(MoveDirection.left);
      expect(controller.state, same(initial));
      expect(controller.tutorialLoaded, isFalse);
      store.loaded.complete(true);
      await controller.ready;
      expect(controller.canMove, isTrue);
    });

    test(
      'does not notify after disposal with a pending tutorial read',
      () async {
        final store = _DeferredTutorialStore();
        final controller = PlayController(tutorialStore: store);
        var notifications = 0;
        controller
          ..addListener(() => notifications++)
          ..dispose();
        store.loaded.complete(false);
        await controller.ready;
        expect(notifications, 0);
        expect(controller.canMove, isFalse);
      },
    );

    test('a late read cannot show a dismissed tutorial again', () async {
      final store = _DeferredTutorialStore();
      final controller = PlayController(tutorialStore: store);
      addTearDown(controller.dispose);
      await controller.dismissTutorial();
      expect(store.saved, isTrue);
      store.loaded.complete(false);
      await controller.ready;
      expect(controller.showTutorial, isFalse);
      expect(controller.canMove, isTrue);
    });

    test(
      'storage failures show instructions and do not block dismissal',
      () async {
        final controller = PlayController(
          tutorialStore: _UnavailableTutorialStore(),
        );
        addTearDown(controller.dispose);
        await controller.ready;
        expect(controller.showTutorial, isTrue);
        expect(controller.canMove, isFalse);
        await controller.dismissTutorial();
        expect(controller.showTutorial, isFalse);
        expect(controller.canMove, isTrue);
      },
    );

    test(
      'uses only engine randomness and publishes only changed moves',
      () async {
        final controller = PlayController(
          random: Random(25),
          tutorialStore: _SeenTutorialStore(),
        );
        addTearDown(controller.dispose);
        await controller.ready;
        final random = Random(25);
        var expected = GameState.start(
          configuration: GameConfiguration(),
          random: random,
        );
        var expectedNotifications = 0;
        var notifications = 0;
        controller.addListener(() => notifications++);
        for (final direction in List.generate(
          80,
          (index) => MoveDirection.values[index % 4],
        )) {
          final previous = expected;
          if (expected.status == GameStatus.inProgress) {
            expected = expected.move(direction: direction, random: random);
          }
          if (!identical(previous, expected)) expectedNotifications++;
          controller.move(direction);
          expect(controller.state.board, expected.board);
          expect(controller.state.score, expected.score);
          expect(controller.state.movesMade, expected.movesMade);
        }
        expect(notifications, expectedNotifications);
      },
    );
  });
  group('Play controller', () {
    late PlayController controller;

    setUp(() async {
      controller = PlayController(
        random: Random(42),
        tutorialStore: _SeenTutorialStore(),
      );
      await controller.ready;
    });

    tearDown(() => controller.dispose());

    test('starts a classic game with two tiles and zero score', () {
      final state = controller.state;
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
      final previousState = controller.state;
      final direction = MoveDirection.values.firstWhere(
        (direction) =>
            previousState.move(direction: direction, random: Random(42)) !=
            previousState,
      );

      controller.move(direction);

      final nextState = controller.state;
      expect(nextState, isNot(same(previousState)));
      expect(nextState.movesMade, 1);
      expect(previousState.movesMade, 0);
    });

    test('starts a fresh session with the same configuration', () {
      final previousState = controller.state;

      controller.startNewGame();

      final nextState = controller.state;
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

final class _SeenTutorialStore implements PlayTutorialStore {
  @override
  Future<bool> hasSeenTutorial() async => true;

  @override
  Future<void> markTutorialSeen() async {}
}

final class _DeferredTutorialStore implements PlayTutorialStore {
  final loaded = Completer<bool>();
  bool saved = false;
  @override
  Future<bool> hasSeenTutorial() => loaded.future;
  @override
  Future<void> markTutorialSeen() async => saved = true;
}

final class _UnavailableTutorialStore implements PlayTutorialStore {
  @override
  Future<bool> hasSeenTutorial() async =>
      throw StateError('Unavailable storage');
  @override
  Future<void> markTutorialSeen() async =>
      throw Exception('Unavailable storage');
}
