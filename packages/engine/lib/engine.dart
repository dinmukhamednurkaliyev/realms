/// The framework-independent public API for the Realms game engine.
///
/// Consumers can create or restore a `GameState`, perform moves, and render
/// the resulting board and events without importing internal algorithms.
library;

export 'src/game_board.dart' show GameBoard;
export 'src/game_configuration.dart' show GameConfiguration;
export 'src/game_events.dart'
    show TileMerge, TileMovement, TilePosition, TileSpawn;
export 'src/game_objective.dart' show GameObjective, ReachTileLevelObjective;
export 'src/game_state.dart' show GameMoveResult, GameState;
export 'src/move_direction.dart' show MoveDirection;
