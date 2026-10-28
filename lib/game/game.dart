/// The consumer-facing API of the Realms Game feature.
///
/// Applications can create a `State`, perform moves, inspect events and
/// game status, and select campaign levels without importing board algorithms.
/// The shared engine remains independent of Flutter and concrete game modes.
library;

export 'engine/board.dart' show Board, BoardPosition;
export 'engine/configuration.dart' show Configuration;
export 'engine/events.dart' show TileMerge, TileMovement, TileSpawn;
export 'engine/mechanics.dart' show MoveDirection;
export 'engine/objectives.dart' show Objective, ReachTileLevelObjective;
export 'engine/state.dart' show MoveResult, State, Status;
export 'modes/campaign.dart' show CampaignLevel;
export 'screens/play.dart' show PlayScreen;
