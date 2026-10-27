# Realms engine

A pure Dart evolution puzzle engine. Tiles are integer civilization levels;
`null` is an empty cell. Rendering, artwork, animation, and storage belong to the
application.

## Basic game loop

```dart
import 'dart:math';

import 'package:engine/engine.dart';

void main() {
  final random = Random(42);
  final configuration = GameConfiguration();
  var state = GameState.start(configuration: configuration, random: random);

  final result = state.moveWithResult(
    direction: MoveDirection.left,
    random: random,
  );
  state = result.state;

  print('Total: ${state.score}; gained: ${result.scoreGained}');
  for (final movement in result.movements) {
    print('Level ${movement.level}: ${movement.from} -> ${movement.to}');
  }
  for (final merge in result.merges) {
    print('${merge.first} + ${merge.second} -> '
        '${merge.destination}, level ${merge.level}');
  }
  final spawn = result.spawnedTile;
  if (spawn != null) {
    print('Spawned level ${spawn.level} at ${spawn.position}');
  }
  if (state.isGameOver) {
    print('Game ended: ${state.outcome.name}');
  }
}
```

Keep the random source for the session and pass it to each move. Use `move` when
only the resulting state is needed; it delegates to `moveWithResult`.
`GameState(board: board, configuration: configuration, score: score)` restores
the supplied snapshot without spawning. Supply the original configuration to
retain custom rules.

## Rules and contracts

- Defaults: 4 rows, 4 columns, 2 starting tiles, maximum level 50, spawn weights
  `{1: 9, 2: 1}`, and score multiplier 10. Positive rectangular dimensions,
  including a single row or column, are supported.
- Equal tiles below the configured maximum merge from the destination edge
  inward. Each source merges once; newly merged tiles cannot merge again during
  that move. Maximum-level tiles can still slide.
- Each merge awards `mergeScoreMultiplier * mergedLevel * mergedLevel` points.
  `scoreGained` describes this move; `state.score` is the accumulated total.
- Every successful move spawns one tile. An ineffective move returns the
  original state, zero points, no events, and consumes no random values.
- Each spawn enumerates empty positions in row-major order, calls
  `nextInt(emptyCellCount)`, then calls `nextDouble()` for weighted level
  selection. The configured weight map's iteration order is significant.
- Boards, configurations, states, and public event collections are immutable.
  Successful moves retain the same configuration instance. Earlier snapshots
  remain valid.
- `BoardPosition` identifies any cell, occupied or empty, with zero-based row
  and column indices. `TilePosition` remains a compatible alias for existing
  consumers.
- Movement events report original tile levels; merge events report resulting
  tile levels. Both merge source positions refer to the board before movement.
  Stationary sources appear in merge events without redundant movement events.
  A spawn is a separate event.
- `canMove` checks whether any direction changes the board before spawning.
  Empty boards and single cells have no legal moves; full boards may still allow
  merges. Reaching the maximum level alone is not victory.
- `outcome` is `won` when the configured objective is complete, otherwise `lost`
  when no moves remain, otherwise `inProgress`. Victory takes priority over a
  blocked board. `isGameOver` includes both victory and defeat. Moves remain
  available after victory; the application decides whether to allow them.
- `CampaignLevel` pairs a positive stage number with a configuration that has an
  objective. `ReachTileLevelObjective` accepts a tile at or above its target.
  Custom `GameObjective` implementations must be immutable and deterministic.

Game modes describe the overall way play is organized. Campaign uses
`CampaignLevel` definitions for its progression stages; a stage's `number` is
independent of the evolution level stored in each board tile. Endless games can
use `GameConfiguration` directly without a Campaign stage. Objectives and basic
mechanics are shared across modes, and `GameState` evaluates them without depending
on Campaign definitions.

## Responsibilities and execution

| File | Responsibility |
| --- | --- |
| [`game/board.dart`](lib/src/game/board.dart) | Board positions, deeply immutable rectangular cells, structural validation, access, equality, and hashing. |
| [`game/configuration.dart`](lib/src/game/configuration.dart) | Gameplay rule parameters and their validation. |
| [`game/objectives.dart`](lib/src/game/objectives.dart) | The objective contract and tile-level objective implementation. |
| [`game/events.dart`](lib/src/game/events.dart) | Immutable movement, merge, and spawn descriptions using board positions. |
| [`game/state.dart`](lib/src/game/state.dart) | Snapshot validation, initialization, outcomes, move results, and transition coordination. |
| [`game/mechanics.dart`](lib/src/game/mechanics.dart) | Directions, traversal, sliding, merging, spawning, weighted selection, and their event generation. |
| [`modes/campaign.dart`](lib/src/modes/campaign.dart) | Campaign level definitions composing a configuration and a stage number. |

Import `package:engine/engine.dart` for the supported public API. The source files
are implementation details. `src/game/` owns reusable gameplay logic, while
`src/modes/` owns concrete mode definitions. Dependencies flow from modes into
game; shared game modules never import concrete modes. Each module is a separate
Dart library with explicit imports. State transitions depend on mechanics,
configuration, board, and event values. Mechanics depend on boards and events,
without importing state or
configuration. Events and objectives depend only on boards; configuration depends
on objectives, and Campaign definitions depend on configuration. Configuration
has no dependency on Campaign. No engine code depends on Flutter or persistence.

Mechanics expose `canMoveBoard`, `moveBoard`, and `spawnTile` for internal state
coordination. They receive validated boards and rule parameters; movement and
spawning return immutable board/event records. These functions are public for
cross-library calls, but `engine.dart` exports only `MoveDirection` from the
mechanics module. Line merging, coordinate traversal, and weighted selection remain
library-private. There are no shared `part` files or mechanics wrapper classes.

`GameState` owns when mechanics run, the unchanged-move guard, scoring, outcomes,
and the next snapshot. Objectives own reusable victory criteria;
`modes/campaign.dart` owns Campaign stage definitions independently of shared game
configurations.

Mutable working rows and event lists stay inside those operations; boards and
public results freeze their collections before exposing them. A move's `changed`
flag is derived from its movement and merge events, independently of spawning.
Under the current rules, every changed move also spawns exactly one tile.

A move follows this sequence:

`direction -> movement/merging -> unchanged guard -> spawn -> score -> next state/result`

Status queries scan adjacent cells once, stopping at the first available slide or
merge. An occupied cell next to an empty cell permits movement; otherwise a pair
must satisfy the same merge predicate used by actual movement. The query creates
no moved boards or events and never uses randomness. Empty boards and single
cells correctly have no moves. Status is derived on demand, without a cache.

## Application boundary

The Flutter entry point is currently empty. Input coordination, random-source
ownership, rendering, animation timing, campaign selection, and persistence belong
in the application when needed. Movement, merge, and spawn events already provide
the domain information needed for rendering a move.

Restoring a snapshot does not reproduce future random draws. Replay requires the
same random sequence, rules, and actions; a seed alone is not a mid-session random
state. Persistence must also preserve the configuration's spawn-weight order.
The engine supplies neither storage nor replay infrastructure.

## Verification

Tests mirror the domain boundaries: shared game suites live in `test/game/`,
and Campaign tests live in `test/modes/`. State tests cover complete transitions,
while mechanics, events, scoring, outcomes, and move availability have focused
suites. Board, configuration, objectives, and Campaign tests cover their
respective contracts. CI discovers `*_test.dart` files recursively through the
same verification task used locally.

From the repository root, run `mise run test:engine` for engine tests.
Run `mise run fix` and review its changes, then run `mise run verify` for formatting,
dependency ordering, application/engine analysis, spelling, and the full test suite.
