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
    print('No legal moves remain.');
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
- Event positions use zero-based row and column indices. Movement levels are
  original levels; merge levels are resulting levels. Both merge source
  positions refer to the board before movement. Stationary sources appear in
  merge events without redundant movement events. A spawn is a separate event.
- `hasLegalMoves` checks whether any direction changes the board before spawning.
  `isGameOver` is its inverse. Empty boards and single cells have no legal moves;
  full boards may still allow merges. Reaching the maximum level is not victory.

## Responsibilities and execution

| Component | Responsibility |
| --- | --- |
| `GameBoard` | Deeply immutable rectangular cells, structural validation, access, equality, and hashing. |
| `GameConfiguration` | Validated dimensions, evolution limit, initial tile count, spawn weights, and score multiplier. |
| `GameState` | Validated board/configuration/score snapshot, initialization, transitions, and status queries. |
| Private `_BoardMovement` | Direction normalization, `_mergeRow`, and movement/merge events. |
| Private `_TileSpawner` | Empty-cell selection, weighted level selection, and spawn information. |
| `GameMoveResult` | Immutable next state, change flag, score gain, and events. |

A move follows this sequence:

`direction -> movement/merging -> unchanged guard -> spawn -> score -> next state/result`

Status queries reuse the same movement operation for up to four directions,
stopping at the first changed board. They never spawn, score, or access randomness.
This also constructs temporary movement results; for small puzzle boards, sharing
the proven rules is preferable to a separate optimized status algorithm. Status
is derived on demand, with no stored status or cache to synchronize.

## Future systems: decisions still needed

- **Endless:** The base loop already continues until no legal moves remain.
  No mode class or maximum-level victory rule is needed. Difficulty curves and
  the balance of board sizes, weights, and score rewards require playtesting.
- **Campaign:** Once objectives are finalized, a stage can pair configuration
  with explicit objective criteria evaluated against the resulting state.
  Keep stage identifiers separate from tile levels. Decide objective combination,
  success/failure precedence, constraints, and progression before implementing.
- **Biomes:** Visual themes belong in Flutter. Gameplay-affecting biomes need
  concrete rules first; existing configuration can express only its current
  dimensions, counts, levels, weights, and multiplier.
- **Modifiers:** Movement currently supports all four directions and one merge
  rule; successful moves always spawn once and use the fixed scoring formula.
  Actual restrictions or changed rules would need focused changes to their
  owning components and status tests. Do not introduce a generic rule pipeline.
- **Save/restore and replay:** Persist board, score, configuration, and spawn
  weight order outside the engine. Snapshot restoration alone does not reproduce
  future random draws. Reliable replay needs the same random sequence, rule
  version, and actions. Durable continuation needs a defined reproducible random
  source/state format or a draw log; a seed alone is not an arbitrary mid-session
  random-state snapshot. No persistence or replay infrastructure is supplied.
- **Flutter animations:** Use movement, merge, and spawn events directly.
  Animation timing, input coordination, and tile assets remain in Flutter.

The next milestone is one playable Flutter screen: render the board, accept
direction input, display score and game over, and restart through `GameState.start`.

## Verification

From the repository root, run `mise run test:engine` for engine tests.
Run `mise run fix` and review its changes, then run `mise run verify` for formatting,
dependency ordering, application/engine analysis, spelling, and the full test suite.
