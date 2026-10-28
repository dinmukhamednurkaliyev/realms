/// The Flutter-independent public API of the Realms game engine.
///
/// Applications can create a `GameState`, perform moves, inspect events and
/// game status, and select campaign levels without importing board algorithms.
library;

export 'engine/board.dart' show BoardPosition, GameBoard;
export 'engine/configuration.dart' show GameConfiguration;
export 'engine/events.dart' show TileMerge, TileMovement, TileSpawn;
export 'engine/mechanics.dart' show MoveDirection;
export 'engine/objectives.dart' show GameObjective, ReachTileLevelObjective;
export 'engine/state.dart' show GameMoveResult, GameState, GameStatus;
export 'modes/campaign.dart' show CampaignLevel;
