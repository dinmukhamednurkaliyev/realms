/// The Flutter-independent public API of the Realms game engine.
///
/// Applications can create a `GameState`, perform moves, inspect events and
/// outcomes, and select campaign levels without importing board algorithms.
library;

export 'src/game/board.dart' show BoardPosition, GameBoard, TilePosition;
export 'src/game/configuration.dart' show GameConfiguration;
export 'src/game/events.dart' show TileMerge, TileMovement, TileSpawn;
export 'src/game/mechanics.dart' show MoveDirection;
export 'src/game/objectives.dart' show GameObjective, ReachTileLevelObjective;
export 'src/game/state.dart' show GameMoveResult, GameOutcome, GameState;
export 'src/modes/campaign.dart' show CampaignLevel;
