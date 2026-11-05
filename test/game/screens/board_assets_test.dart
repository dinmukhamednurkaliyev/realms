import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:realms/app/assets/assets.dart';
import 'package:realms/game/engine/engine.dart';
import 'package:realms/game/screens/board.dart';

void main() {
  testWidgets('uses the first three forest levels without terrain artwork', (
    tester,
  ) async {
    final board = GameBoard(
      rows: [
        [null, 1, 2, 3, 4],
      ],
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Center(
            child: SizedBox(
              width: 500,
              height: 100,
              child: PlayBoard(
                board: board,
                previousBoard: null,
                lastMove: null,
                progress: 1,
              ),
            ),
          ),
        ),
      ),
    );

    final loadedPaths = tester.widgetList<Image>(find.byType(Image)).map((
      image,
    ) {
      final provider = image.image;
      final asset = provider is ResizeImage ? provider.imageProvider : provider;
      return (asset as AssetImage).assetName;
    }).toList();

    expect(loadedPaths, hasLength(3));
    expect(loadedPaths, contains(assets.game.forest.levels.one));
    expect(loadedPaths, contains(assets.game.forest.levels.two));
    expect(loadedPaths, contains(assets.game.forest.levels.three));

    // Empty cells use a Flutter background; level 4 is a numeric placeholder.
    expect(find.text('4'), findsOneWidget);
    expect(find.text('1'), findsNothing);
    expect(find.text('2'), findsNothing);
    expect(find.text('3'), findsNothing);

    for (var index = 0; index < 5; index++) {
      expect(find.byKey(ValueKey('board_cell_$index')), findsOneWidget);
    }
  });
}
