import 'package:realms/game/engine/engine.dart';
import 'package:test/test.dart';

void main() {
  group('GameConfiguration', () {
    test('uses default values', () {
      final configuration = GameConfiguration();

      expect(configuration.rowCount, 4);
      expect(configuration.columnCount, 4);
      expect(configuration.initialTileCount, 2);
      expect(configuration.maxTileLevel, 50);
      expect(configuration.spawnWeights, {1: 9, 2: 1});
    });

    test('supports custom settings', () {
      final configuration = GameConfiguration(
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
      expect(() => GameConfiguration(rowCount: 0), throwsArgumentError);

      expect(() => GameConfiguration(columnCount: -1), throwsArgumentError);
    });

    test('rejects invalid initial tile counts', () {
      expect(() => GameConfiguration(initialTileCount: 0), throwsArgumentError);

      expect(
        () =>
            GameConfiguration(rowCount: 2, columnCount: 2, initialTileCount: 5),
        throwsArgumentError,
      );
    });

    test('rejects invalid maximum tile levels', () {
      expect(() => GameConfiguration(maxTileLevel: 0), throwsArgumentError);
    });

    test('rejects spawn levels outside the evolution range', () {
      expect(
        () => GameConfiguration(maxTileLevel: 3, spawnWeights: {4: 1}),
        throwsArgumentError,
      );
    });

    test('rejects empty or non-positive spawn weights', () {
      expect(() => GameConfiguration(spawnWeights: {}), throwsArgumentError);

      expect(
        () => GameConfiguration(spawnWeights: {1: 0}),
        throwsArgumentError,
      );

      expect(
        () => GameConfiguration(spawnWeights: {1: -1}),
        throwsArgumentError,
      );
    });

    test('protects spawn weights from external changes', () {
      final spawnWeights = {1: 9, 2: 1};

      final configuration = GameConfiguration(spawnWeights: spawnWeights);

      spawnWeights[1] = 100;

      expect(configuration.spawnWeights, {1: 9, 2: 1});

      expect(() => configuration.spawnWeights[1] = 100, throwsUnsupportedError);
    });

    test('rejects spawn totals outside the exact integer range', () {
      const maximumExactInteger = 9007199254740991;

      expect(
        () => GameConfiguration(spawnWeights: {1: maximumExactInteger + 1}),
        throwsArgumentError,
      );
      expect(
        () => GameConfiguration(spawnWeights: {1: maximumExactInteger, 2: 1}),
        throwsArgumentError,
      );
      expect(
        GameConfiguration(spawnWeights: {1: maximumExactInteger}).spawnWeights,
        {1: maximumExactInteger},
      );
    });
  });
}
