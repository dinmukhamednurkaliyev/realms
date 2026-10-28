import 'package:realms/game/engine/board.dart';

/// Describes an original tile sliding to a different board position.
///
/// Stationary tiles do not produce movement events. A tile which participates
/// in a merge produces a movement event only if its position changes.
final class TileMovement {
  /// Describes a moving tile at its level before any merge.
  const new({required this.from, required this.to, required this.level});

  /// The original position of the tile.
  final BoardPosition from;

  /// The position reached by the tile.
  final BoardPosition to;

  /// The tile's level before merging.
  final int level;
}

/// Describes two original tiles combining at a destination position.
///
/// Both sources refer to positions before the move. The destination is where
/// the new tile appears, and [level] is its resulting level.
final class TileMerge {
  /// Records the two original tiles and the resulting tile.
  const new({
    required this.firstSource,
    required this.secondSource,
    required this.destination,
    required this.level,
  });

  /// The original position of the source nearest the destination edge.
  final BoardPosition firstSource;

  /// The original position of the other source participating in the merge.
  final BoardPosition secondSource;

  /// The location of the merged tile.
  final BoardPosition destination;

  /// The level of the merged tile.
  final int level;
}

/// Describes a tile spawned into an empty cell at startup or after a move.
final class TileSpawn {
  /// Records the spawn position and level.
  const new({required this.position, required this.level});

  /// The empty position selected for the new tile.
  final BoardPosition position;

  /// The level selected from the configured spawn weights.
  final int level;
}
