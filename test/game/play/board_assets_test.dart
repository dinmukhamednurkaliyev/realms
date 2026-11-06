import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:realms/app/asset/asset.dart';
import 'package:realms/game/engine/engine.dart';
import 'package:realms/game/play/board.dart';

void main() {
  testWidgets(
    'maps all six levels to their exact artwork and falls back above six',
    (tester) async {
      final board = GameBoard(
        rows: [
          [null, 1, 2, 3, 4, 5, 6, 7],
        ],
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(
              child: SizedBox(
                width: 800,
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
        final asset = provider is ResizeImage
            ? provider.imageProvider
            : provider;
        return (asset as AssetImage).assetName;
      }).toList();

      expect(loadedPaths, [
        assets.game.images.forest.levels.one,
        assets.game.images.forest.levels.two,
        assets.game.images.forest.levels.three,
        assets.game.images.forest.levels.four,
        assets.game.images.forest.levels.five,
        assets.game.images.forest.levels.six,
      ]);

      // Empty cells have no artwork; unsupported levels remain readable.
      expect(find.text('7'), findsOneWidget);
      for (var level = 1; level <= 6; level++) {
        expect(find.text('$level'), findsNothing);
      }

      for (var index = 0; index < 8; index++) {
        expect(find.byKey(ValueKey('board_cell_$index')), findsOneWidget);
      }
    },
  );
  testWidgets('all six image resources are bundled and decode successfully', (
    tester,
  ) async {
    final levels = assets.game.images.forest.levels;
    final paths = [
      levels.one,
      levels.two,
      levels.three,
      levels.four,
      levels.five,
      levels.six,
    ];
    await tester.runAsync(() async {
      final manifest = await AssetManifest.loadFromAssetBundle(rootBundle);
      for (final path in paths) {
        expect(manifest.listAssets(), contains(path));
        final bytes = await rootBundle.load(path);
        final image = await decodeImageFromList(bytes.buffer.asUint8List());
        expect(image.width, greaterThan(0));
        expect(image.height, greaterThan(0));
        image.dispose();
      }
    });
  });

  testWidgets(
    'failed artwork loads display the tile level without an exception',
    (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: DefaultAssetBundle(
            bundle: _FailingImages(),
            child: Center(
              child: SizedBox(
                width: 100,
                height: 100,
                child: PlayBoard(
                  board: GameBoard(
                    rows: [
                      [1],
                    ],
                  ),
                  previousBoard: null,
                  lastMove: null,
                  progress: 1,
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('1'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
}

final class _FailingImages extends CachingAssetBundle {
  @override
  Future<ByteData> load(String key) {
    if (key.endsWith('.png')) {
      return Future.error(StateError('Image unavailable'));
    }
    return rootBundle.load(key);
  }
}
