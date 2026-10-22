import 'package:engine/engine.dart';
import 'package:test/test.dart';

void main() {
  group('GameConfiguration', () {
    test('uses default values', () {
      final configuration = GameConfiguration();

      expect(configuration.rowCount, 4);
      expect(configuration.columnCount, 4);
      expect(configuration.initialTileCount, 2);
    });

    test('supports custom configuration', () {
      final configuration = GameConfiguration(
        rowCount: 5,
        columnCount: 5,
        initialTileCount: 3,
      );

      expect(configuration.rowCount, 5);
      expect(configuration.columnCount, 5);
      expect(configuration.initialTileCount, 3);
    });

    test('rejects more initial tiles than available cells', () {
      expect(
        () =>
            GameConfiguration(rowCount: 2, columnCount: 2, initialTileCount: 5),
        throwsArgumentError,
      );
    });
  });
}
