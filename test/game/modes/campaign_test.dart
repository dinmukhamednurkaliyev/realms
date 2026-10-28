import 'dart:math';

import 'package:realms/game/game.dart' as game;
import 'package:test/test.dart';

void main() {
  group('Campaign', () {
    test('defines distinct Campaign stages using shared configuration', () {
      final firstStage = game.CampaignLevel(
        number: 1,
        configuration: game.Configuration(
          rowCount: 3,
          columnCount: 3,
          objective: game.ReachTileLevelObjective(targetLevel: 3),
        ),
      );
      final secondStage = game.CampaignLevel(
        number: 2,
        configuration: game.Configuration(
          objective: game.ReachTileLevelObjective(targetLevel: 5),
        ),
      );

      expect(firstStage.number, 1);
      expect(firstStage.configuration.rowCount, 3);
      expect(secondStage.number, 2);
      expect(secondStage.configuration.rowCount, 4);

      final state = game.State.start(
        configuration: firstStage.configuration,
        random: Random(42),
      );
      expect(state.board.rowCount, 3);
      expect(state.configuration, same(firstStage.configuration));
    });

    test('rejects invalid campaign level numbers', () {
      expect(
        () => game.CampaignLevel(
          number: 0,
          configuration: game.Configuration(
            objective: game.ReachTileLevelObjective(targetLevel: 3),
          ),
        ),
        throwsArgumentError,
      );
    });

    test('requires a victory objective', () {
      expect(
        () =>
            game.CampaignLevel(number: 1, configuration: game.Configuration()),
        throwsArgumentError,
      );
    });
  });
}
