/// Reusable gameplay types, independent of Flutter and concrete game modes.
///
/// Movement and spawning algorithms remain implementation details.
library;

export 'board.dart' show BoardPosition, GameBoard;
export 'configuration.dart' show GameConfiguration;
export 'events.dart' show TileMerge, TileMovement, TileSpawn;
export 'mechanics.dart' show MoveDirection;
export 'objectives.dart' show GameObjective, ReachTileLevelObjective;
export 'state.dart' show GameMoveResult, GameState, GameStatus;
