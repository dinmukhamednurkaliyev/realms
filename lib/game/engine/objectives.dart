import 'board.dart';

/// A victory condition evaluated against an immutable game snapshot.
///
/// Objectives describe success independently of available moves.
/// Implementations must be immutable and evaluate the supplied board and score
/// deterministically, without side effects or randomness, so retained snapshots
/// remain valid.
abstract interface class Objective {
  /// Whether the given board and accumulated score satisfy this objective.
  bool isCompleted({required Board board, required int score});
}

/// A victory condition requiring at least one tile to reach [targetLevel].
///
/// A tile at a higher level also satisfies the objective. The objective can
/// already be complete when a game starts or a saved game is restored.
final class ReachTileLevelObjective implements Objective {
  /// Creates a target level, which must be positive.
  ///
  /// The game configuration separately checks that the target does not exceed
  /// its maximum tile level.
  new({required this.targetLevel}) {
    if (targetLevel < 1) {
      throw ArgumentError.value(
        targetLevel,
        'targetLevel',
        'Must be greater than zero.',
      );
    }
  }

  /// The minimum tile level required to complete the objective.
  final int targetLevel;

  @override
  bool isCompleted({required Board board, required int score}) {
    for (final row in board.rows) {
      for (final tileLevel in row) {
        if (tileLevel != null && tileLevel >= targetLevel) {
          return true;
        }
      }
    }

    return false;
  }
}
