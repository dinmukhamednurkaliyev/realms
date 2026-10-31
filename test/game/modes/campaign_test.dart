import 'dart:math';

import 'package:realms/game/engine/engine.dart';
import 'package:realms/game/modes/modes.dart';
import 'package:test/test.dart';

void main() {
  group('Campaign', () {
    test('defines distinct Campaign stages using shared configuration', () {
      final firstStage = CampaignLevel(
        number: 1,
        configuration: GameConfiguration(
          rowCount: 3,
          columnCount: 3,
          objective: ReachTileLevelObjective(targetLevel: 3),
        ),
      );
      final secondStage = CampaignLevel(
        number: 2,
        configuration: GameConfiguration(
          objective: ReachTileLevelObjective(targetLevel: 5),
        ),
      );

      expect(firstStage.number, 1);
      expect(firstStage.configuration.rowCount, 3);
      expect(secondStage.number, 2);
      expect(secondStage.configuration.rowCount, 4);

      final state = GameState.start(
        configuration: firstStage.configuration,
        random: Random(42),
      );
      expect(state.board.rowCount, 3);
      expect(state.configuration, same(firstStage.configuration));
    });

    test('rejects invalid campaign level numbers', () {
      expect(
        () => CampaignLevel(
          number: 0,
          configuration: GameConfiguration(
            objective: ReachTileLevelObjective(targetLevel: 3),
          ),
        ),
        throwsArgumentError,
      );
    });

    test('requires a victory objective', () {
      expect(
        () => CampaignLevel(number: 1, configuration: GameConfiguration()),
        throwsArgumentError,
      );
    });
  });
}
