import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:realms/app/assets/assets.dart';
import 'package:realms/game/engine/engine.dart';
import 'package:realms/game/screens/board.dart';

void main() {
  testWidgets('registers slide and merge sounds', (tester) async {
    final paths = [assets.game.sounds.slide, assets.game.sounds.merge];

    expect(paths.toSet(), hasLength(2));

    for (final path in paths) {
      final data = await rootBundle.load(path);
      expect(data.lengthInBytes, greaterThan(44), reason: path);
    }
  });

  testWidgets('merges pulse before the new tile pops onto the board', (
    tester,
  ) async {
    final initial = GameState(
      board: GameBoard(
        rows: [
          [1, null, 1, null],
        ],
      ),
      configuration: GameConfiguration(rowCount: 1, initialTileCount: 1),
    );

    final move = initial.moveWithResult(
      direction: MoveDirection.left,
      random: Random(42),
    );

    final spawn = move.spawnedTile!.position;
    final spawnKey = ValueKey('tile_${spawn.rowIndex}_${spawn.columnIndex}');

    Widget frame(double progress) => MaterialApp(
      home: Scaffold(
        body: Center(
          child: SizedBox(
            width: 400,
            height: 100,
            child: PlayBoard(
              board: move.state.board,
              previousBoard: initial.board,
              lastMove: move,
              progress: progress,
            ),
          ),
        ),
      ),
    );

    await tester.pumpWidget(frame(0.30));

    expect(find.byKey(const ValueKey('moving_tile_0_2')), findsOneWidget);
    expect(find.byKey(spawnKey), findsNothing);

    await tester.pumpWidget(frame(0.64));

    expect(find.byKey(const ValueKey('moving_tile_0_2')), findsNothing);
    expect(find.byKey(const ValueKey('tile_0_0')), findsOneWidget);
    expect(find.byKey(spawnKey), findsNothing);

    final mergeTransform = tester.widget<Transform>(
      find
          .ancestor(
            of: find.byKey(const ValueKey('tile_0_0')),
            matching: find.byType(Transform),
          )
          .first,
    );

    expect(mergeTransform.transform.storage[0], greaterThan(1.05));

    await tester.pumpWidget(frame(0.88));

    expect(find.byKey(spawnKey), findsOneWidget);

    final spawnOpacity = tester.widget<Opacity>(
      find
          .ancestor(of: find.byKey(spawnKey), matching: find.byType(Opacity))
          .first,
    );

    expect(spawnOpacity.opacity, inExclusiveRange(0, 1));

    await tester.pumpWidget(frame(1));

    expect(find.byKey(spawnKey), findsOneWidget);
    expect(find.byKey(const ValueKey('moving_tile_0_2')), findsNothing);
  });
}
