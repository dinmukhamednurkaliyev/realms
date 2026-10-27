import 'package:engine/src/game/board.dart';

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
/// [first] and [second] refer to positions before the move. The destination
/// is where the new tile appears, and [level] is its resulting level.
final class TileMerge {
  /// Records the two original tiles and the resulting tile.
  const new({
    required this.first,
    required this.second,
    required this.destination,
    required this.level,
  });

  /// The original position of the source nearest the destination edge.
  final BoardPosition first;

  /// The original position of the other source participating in the merge.
  final BoardPosition second;

  /// The location of the merged tile.
  final BoardPosition destination;

  /// The level of the merged tile.
  final int level;
}

/// Describes a randomly spawned tile after a successful move.
final class TileSpawn {
  /// Records the spawn position and level.
  const new({required this.position, required this.level});

  /// The empty position selected for the new tile.
  final BoardPosition position;

  /// The level selected from the configured spawn weights.
  final int level;
}
