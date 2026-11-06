import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:realms/app/asset/asset.dart';
import 'package:realms/app/audio/audio.dart';
import 'package:realms/app/localization/localization.dart';
import 'package:realms/game/engine/engine.dart';
import 'package:realms/game/play/board.dart';
import 'package:realms/game/play/controller.dart';
import 'package:realms/game/play/screen.dart';

void main() {
  testWidgets('registers slide and merge sounds', (tester) async {
    final paths = [assets.game.sounds.slide, assets.game.sounds.merge];

    expect(paths.toSet(), hasLength(2));

    for (final path in paths) {
      final data = await rootBundle.load(path);
      expect(data.lengthInBytes, greaterThan(44), reason: path);
    }
  });

  group('move feedback', () {
    late PlayController controller;
    late _RecordingAudio audio;

    setUp(() async {
      // Two level-one tiles at the start of the first row.
      controller = PlayController(
        random: _FirstCellRandom(),
        tutorialStore: _SeenTutorial(),
      );
      audio = _RecordingAudio();
      await controller.ready;
    });

    tearDown(() => controller.dispose());

    testWidgets('unchanged moves are silent', (tester) async {
      await tester.pumpWidget(_screen(controller, audio));
      await tester.pumpAndSettle();
      final initial = controller.state;
      controller.move(MoveDirection.up);
      await tester.pumpAndSettle();

      expect(controller.state, same(initial));
      expect(audio.effects, isEmpty);
    });

    testWidgets('slides once without a merge effect for a non-merging move', (
      tester,
    ) async {
      await tester.pumpWidget(_screen(controller, audio));
      await tester.pumpAndSettle();
      controller.move(MoveDirection.down);
      await tester.pumpAndSettle();

      expect(controller.lastMove!.merges, isEmpty);
      expect(controller.lastMove!.spawnedTile, isNotNull);
      expect(audio.effects, [SoundEffect.slide]);
    });

    testWidgets('merge feedback follows sliding and never repeats on rebuild', (
      tester,
    ) async {
      await tester.pumpWidget(_screen(controller, audio));
      await tester.pumpAndSettle();
      controller.move(MoveDirection.left);
      expect(controller.lastMove!.merges, hasLength(1));
      expect(audio.effects, [SoundEffect.slide]);

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      expect(audio.effects, [SoundEffect.slide]);
      await tester.pump(const Duration(milliseconds: 30));
      expect(audio.effects, [SoundEffect.slide, SoundEffect.merge]);
      await tester.pumpAndSettle();

      await tester.pumpWidget(_screen(controller, audio, locale: 'ru'));
      await tester.pumpAndSettle();
      // Tutorial notifications also leave the snapshot and effects unchanged.
      await controller.dismissTutorial();
      await tester.pumpAndSettle();
      expect(audio.effects, [SoundEffect.slide, SoundEffect.merge]);
      expect(audio.initializations, 1);
      expect(audio.volumes, everyElement(1)); // Existing debug volume override.
    });

    testWidgets('a frame skipping past completion still plays the merge once', (
      tester,
    ) async {
      await tester.pumpWidget(_screen(controller, audio));
      await tester.pumpAndSettle();
      controller.move(MoveDirection.left);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pumpAndSettle();

      expect(audio.effects, [SoundEffect.slide, SoundEffect.merge]);
    });

    testWidgets('restart cancels pending feedback and keeps playback usable', (
      tester,
    ) async {
      await tester.pumpWidget(_screen(controller, audio));
      await tester.pumpAndSettle();
      controller.move(MoveDirection.left);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));
      controller.startNewGame();
      await tester.pumpAndSettle();
      expect(audio.effects, [SoundEffect.slide]);

      controller.move(MoveDirection.left);
      await tester.pumpAndSettle();
      expect(audio.effects, [
        SoundEffect.slide,
        SoundEffect.slide,
        SoundEffect.merge,
      ]);
    });

    testWidgets('replacing the session cancels its pending merge', (
      tester,
    ) async {
      await tester.pumpWidget(_screen(controller, audio));
      await tester.pumpAndSettle();
      controller.move(MoveDirection.left);
      await tester.pump();

      final replacement = PlayController(
        random: _FirstCellRandom(),
        tutorialStore: _SeenTutorial(),
      );
      addTearDown(replacement.dispose);
      await replacement.ready;
      await tester.pumpWidget(_screen(replacement, audio));
      await tester.pumpAndSettle();
      expect(audio.effects, [SoundEffect.slide]);

      replacement.move(MoveDirection.left);
      await tester.pumpAndSettle();
      expect(audio.effects, [
        SoundEffect.slide,
        SoundEffect.slide,
        SoundEffect.merge,
      ]);
    });

    testWidgets('leaving a screen cancels feedback without owning the audio', (
      tester,
    ) async {
      await tester.pumpWidget(_screen(controller, audio));
      await tester.pumpAndSettle();
      controller.move(MoveDirection.left);
      await tester.pump();
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump(const Duration(milliseconds: 300));
      expect(audio.effects, [SoundEffect.slide]);

      controller.startNewGame();
      await tester.pumpWidget(_screen(controller, audio));
      await tester.pumpAndSettle();
      // New consumers may request initialization; the shared owner caches it.
      expect(audio.initializations, 2);
      expect(audio.effects, [SoundEffect.slide]);
      controller.move(MoveDirection.left);
      await tester.pumpAndSettle();
      expect(audio.effects, [
        SoundEffect.slide,
        SoundEffect.slide,
        SoundEffect.merge,
      ]);
    });

    testWidgets('terminal snapshots never replay effects on input or rebuild', (
      tester,
    ) async {
      final directions = Random(42);
      for (var attempt = 0; attempt < 10000 && controller.canMove; attempt++) {
        controller.move(MoveDirection.values[directions.nextInt(4)]);
      }
      expect(controller.state.status, isNot(GameStatus.inProgress));
      await tester.pumpWidget(_screen(controller, audio));
      await tester.pumpAndSettle();
      controller.move(MoveDirection.left);
      await tester.pumpWidget(_screen(controller, audio, locale: 'ru'));
      await tester.pumpAndSettle();
      expect(audio.effects, isEmpty);
    });
  });

  testWidgets('merges pulse before the new tile pops onto the board', (
    tester,
  ) async {
    final initial = GameState(
      board: GameBoard(
        rows: [
          [1, null, 1, null],
        ],
      ),
      configuration: GameConfiguration(rowCount: 1, initialTileCount: 1),
    );

    final move = initial.moveWithResult(
      direction: MoveDirection.left,
      random: Random(42),
    );

    final spawn = move.spawnedTile!.position;
    final spawnKey = ValueKey('tile_${spawn.rowIndex}_${spawn.columnIndex}');

    Widget frame(double progress) => MaterialApp(
      home: Scaffold(
        body: Center(
          child: SizedBox(
            width: 400,
            height: 100,
            child: PlayBoard(
              board: move.state.board,
              previousBoard: initial.board,
              lastMove: move,
              progress: progress,
            ),
          ),
        ),
      ),
    );

    await tester.pumpWidget(frame(0.30));

    expect(find.byKey(const ValueKey('moving_tile_0_2')), findsOneWidget);
    expect(find.byKey(spawnKey), findsNothing);

    await tester.pumpWidget(frame(0.64));

    expect(find.byKey(const ValueKey('moving_tile_0_2')), findsNothing);
    expect(find.byKey(const ValueKey('tile_0_0')), findsOneWidget);
    expect(find.byKey(spawnKey), findsNothing);

    final mergeTransform = tester.widget<Transform>(
      find
          .ancestor(
            of: find.byKey(const ValueKey('tile_0_0')),
            matching: find.byType(Transform),
          )
          .first,
    );

    expect(mergeTransform.transform.storage[0], greaterThan(1.05));

    await tester.pumpWidget(frame(0.88));

    expect(find.byKey(spawnKey), findsOneWidget);

    final spawnOpacity = tester.widget<Opacity>(
      find
          .ancestor(of: find.byKey(spawnKey), matching: find.byType(Opacity))
          .first,
    );

    expect(spawnOpacity.opacity, inExclusiveRange(0, 1));

    await tester.pumpWidget(frame(1));

    expect(find.byKey(spawnKey), findsOneWidget);
    expect(find.byKey(const ValueKey('moving_tile_0_2')), findsNothing);
  });
}

Widget _screen(
  PlayController controller,
  AudioPlayback audio, {
  String locale = 'en',
}) => MaterialApp(
  locale: Locale(locale),
  localizationsDelegates: AppLocalization.localizationsDelegates,
  supportedLocales: AppLocalization.supportedLocales,
  home: PlayScreen(controller: controller, audio: audio),
);

final class _RecordingAudio implements AudioPlayback {
  int initializations = 0;
  final effects = <SoundEffect>[];
  final volumes = <double>[];

  @override
  Future<void> initialize() async {
    initializations++;
  }

  @override
  void play(SoundEffect effect, {double volume = 1}) {
    effects.add(effect);
    volumes.add(volume);
  }
}

final class _FirstCellRandom implements Random {
  @override
  int nextInt(int max) => 0;

  @override
  double nextDouble() => 0;

  @override
  bool nextBool() => false;
}

final class _SeenTutorial implements PlayTutorialStore {
  @override
  Future<bool> hasSeenTutorial() async => true;

  @override
  Future<void> markTutorialSeen() async {}
}
