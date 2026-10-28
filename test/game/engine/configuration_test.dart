import 'package:realms/game/game.dart' as game;
import 'package:test/test.dart';

void main() {
  group('Configuration', () {
    test('uses default values', () {
      final configuration = game.Configuration();

      expect(configuration.rowCount, 4);
      expect(configuration.columnCount, 4);
      expect(configuration.initialTileCount, 2);
      expect(configuration.maxTileLevel, 50);
      expect(configuration.spawnWeights, {1: 9, 2: 1});
    });

    test('supports custom settings', () {
      final configuration = game.Configuration(
        rowCount: 5,
        columnCount: 6,
        initialTileCount: 3,
        maxTileLevel: 20,
        spawnWeights: {1: 7, 2: 2, 3: 1},
      );

      expect(configuration.rowCount, 5);
      expect(configuration.columnCount, 6);
      expect(configuration.initialTileCount, 3);
      expect(configuration.maxTileLevel, 20);
      expect(configuration.spawnWeights, {1: 7, 2: 2, 3: 1});
    });

    test('rejects non-positive dimensions', () {
      expect(() => game.Configuration(rowCount: 0), throwsArgumentError);

      expect(() => game.Configuration(columnCount: -1), throwsArgumentError);
    });

    test('rejects invalid initial tile counts', () {
      expect(
        () => game.Configuration(initialTileCount: 0),
        throwsArgumentError,
      );

      expect(
        () => game.Configuration(
          rowCount: 2,
          columnCount: 2,
          initialTileCount: 5,
        ),
        throwsArgumentError,
      );
    });

    test('rejects invalid maximum tile levels', () {
      expect(() => game.Configuration(maxTileLevel: 0), throwsArgumentError);
    });

    test('rejects spawn levels outside the evolution range', () {
      expect(
        () => game.Configuration(maxTileLevel: 3, spawnWeights: {4: 1}),
        throwsArgumentError,
      );
    });

    test('rejects empty or non-positive spawn weights', () {
      expect(() => game.Configuration(spawnWeights: {}), throwsArgumentError);

      expect(
        () => game.Configuration(spawnWeights: {1: 0}),
        throwsArgumentError,
      );

      expect(
        () => game.Configuration(spawnWeights: {1: -1}),
        throwsArgumentError,
      );
    });

    test('protects spawn weights from external changes', () {
      final spawnWeights = {1: 9, 2: 1};

      final configuration = game.Configuration(spawnWeights: spawnWeights);

      spawnWeights[1] = 100;

      expect(configuration.spawnWeights, {1: 9, 2: 1});

      expect(() => configuration.spawnWeights[1] = 100, throwsUnsupportedError);
    });
  });
}
