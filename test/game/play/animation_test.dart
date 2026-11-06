import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:realms/app/localization/localization.dart';
import 'package:realms/game/engine/engine.dart';
import 'package:realms/game/play/board.dart';
import 'package:realms/game/play/controller.dart';
import 'package:realms/game/play/screen.dart';

final class _SeenTutorial implements PlayTutorialStore {
  @override
  Future<bool> hasSeenTutorial() async => true;

  @override
  Future<void> markTutorialSeen() async {}
}

Widget _boardAtProgress({
  required GameBoard board,
  required GameBoard? previousBoard,
  required GameMoveResult? move,
  required double progress,
}) {
  return MaterialApp(
    home: Scaffold(
      body: Center(
        child: SizedBox(
          width: 400,
          height: 100,
          child: PlayBoard(
            board: board,
            previousBoard: previousBoard,
            lastMove: move,
            progress: progress,
          ),
        ),
      ),
    ),
  );
}

void main() {
  testWidgets('draws movement, merge, and spawn in that order', (tester) async {
    final initial = GameState(
      board: GameBoard(
        rows: [
          [1, null, 1, null],
        ],
      ),
      configuration: GameConfiguration(rowCount: 1, initialTileCount: 1),
    );
    final result = initial.moveWithResult(
      direction: MoveDirection.left,
      random: Random(42),
    );
    expect(result.changed, isTrue);
    expect(result.merges, hasLength(1));
    expect(result.spawnedTile, isNotNull);
    final spawn = result.spawnedTile!.position;
    final spawnKey = ValueKey('tile_${spawn.rowIndex}_${spawn.columnIndex}');

    Widget frame(double progress) => _boardAtProgress(
      board: result.state.board,
      previousBoard: initial.board,
      move: result,
      progress: progress,
    );

    await tester.pumpWidget(frame(0.3));
    expect(find.byKey(const ValueKey('moving_tile_0_0')), findsOneWidget);
    expect(find.byKey(const ValueKey('moving_tile_0_2')), findsOneWidget);
    expect(find.byKey(const ValueKey('tile_0_0')), findsNothing);

    await tester.pumpWidget(frame(0.7));
    expect(find.byKey(const ValueKey('moving_tile_0_2')), findsNothing);
    expect(find.byKey(const ValueKey('tile_0_0')), findsOneWidget);
    expect(find.byKey(spawnKey), findsNothing);

    await tester.pumpWidget(frame(0.9));
    expect(find.byKey(spawnKey), findsOneWidget);

    await tester.pumpWidget(frame(1));
    expect(find.byKey(spawnKey), findsOneWidget);
    expect(find.byKey(const ValueKey('moving_tile_0_0')), findsNothing);
  });

  testWidgets('ignores input during the animation and supports reset', (
    tester,
  ) async {
    final controller = PlayController(
      random: Random(42),
      tutorialStore: _SeenTutorial(),
    );
    await controller.ready;

    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('en'),
        localizationsDelegates: AppLocalization.localizationsDelegates,
        supportedLocales: AppLocalization.supportedLocales,
        home: PlayScreen(controller: controller),
      ),
    );
    await tester.pumpAndSettle();

    final initialState = controller.state;
    final direction = MoveDirection.values.firstWhere(
      (direction) => !identical(
        initialState.move(direction: direction, random: Random(123)),
        initialState,
      ),
    );
    final key = switch (direction) {
      MoveDirection.left => LogicalKeyboardKey.arrowLeft,
      MoveDirection.right => LogicalKeyboardKey.arrowRight,
      MoveDirection.up => LogicalKeyboardKey.arrowUp,
      MoveDirection.down => LogicalKeyboardKey.arrowDown,
    };

    await tester.sendKeyDownEvent(key);
    await tester.pump(const Duration(milliseconds: 30));
    expect(controller.state.movesMade, 1);
    expect(find.byKey(const ValueKey('play_board')), findsOneWidget);

    await tester.sendKeyUpEvent(key);
    await tester.sendKeyDownEvent(key);
    await tester.pump(const Duration(milliseconds: 30));
    expect(controller.state.movesMade, 1);

    // Reset during the tween: the old movement must disappear immediately.
    await tester.tap(find.byTooltip('New game'));
    await tester.pumpAndSettle();
    expect(controller.state.movesMade, 0);
    expect(controller.state.score, 0);
    expect(find.byKey(const ValueKey('moving_tile_0_0')), findsNothing);

    await tester.pumpWidget(const SizedBox.shrink());
    controller.dispose();
  });
}
