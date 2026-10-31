import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:realms/app/localization/localization.dart';
import 'package:realms/game/engine/engine.dart';
import 'package:realms/game/screens/play.dart';

final class _MemoryTutorialStore implements PlayTutorialStore {
  new({this.seen = false});

  bool seen;

  @override
  Future<bool> hasSeenTutorial() async => seen;

  @override
  Future<void> markTutorialSeen() async {
    seen = true;
  }
}

Widget _testApplication(_MemoryTutorialStore store) {
  return ProviderScope(
    overrides: [playTutorialStoreProvider.overrideWith((ref) => store)],
    child: const MaterialApp(
      locale: Locale('en'),
      localizationsDelegates: Strings.localizationsDelegates,
      supportedLocales: Strings.supportedLocales,
      home: PlayScreen(),
    ),
  );
}

GameState _currentGame(WidgetTester tester) {
  final context = tester.element(find.byType(PlayScreen));
  return ProviderScope.containerOf(context).read(playSessionProvider);
}

MoveDirection _availableDirection(GameState state) {
  return MoveDirection.values.firstWhere(
    (direction) =>
        state.move(direction: direction, random: Random(42)) != state,
  );
}

LogicalKeyboardKey _keyFor(MoveDirection direction) {
  return switch (direction) {
    MoveDirection.left => LogicalKeyboardKey.arrowLeft,
    MoveDirection.right => LogicalKeyboardKey.arrowRight,
    MoveDirection.up => LogicalKeyboardKey.arrowUp,
    MoveDirection.down => LogicalKeyboardKey.arrowDown,
  };
}

LogicalKeyboardKey _wasdKeyFor(MoveDirection direction) {
  return switch (direction) {
    MoveDirection.left => LogicalKeyboardKey.keyA,
    MoveDirection.right => LogicalKeyboardKey.keyD,
    MoveDirection.up => LogicalKeyboardKey.keyW,
    MoveDirection.down => LogicalKeyboardKey.keyS,
  };
}

Offset _swipeFor(MoveDirection direction) {
  return switch (direction) {
    MoveDirection.left => const Offset(-110, 0),
    MoveDirection.right => const Offset(110, 0),
    MoveDirection.up => const Offset(0, -110),
    MoveDirection.down => const Offset(0, 110),
  };
}

void main() {
  testWidgets('shows the tutorial only until it is acknowledged', (
    tester,
  ) async {
    final store = _MemoryTutorialStore();
    await tester.pumpWidget(_testApplication(store));
    await tester.pumpAndSettle();

    expect(find.text('How to Play'), findsOneWidget);
    expect(find.text('Got it!'), findsOneWidget);

    await tester.tap(find.text('Got it!'));
    await tester.pumpAndSettle();

    expect(store.seen, isTrue);
    expect(find.text('How to Play'), findsNothing);

    // A new ProviderScope simulates leaving and reopening the play screen.
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
    await tester.pumpWidget(_testApplication(store));
    await tester.pumpAndSettle();

    expect(find.text('How to Play'), findsNothing);
  });

  testWidgets('arrow keys make one move', (tester) async {
    await tester.pumpWidget(_testApplication(_MemoryTutorialStore(seen: true)));
    await tester.pumpAndSettle();

    final initial = _currentGame(tester);
    final direction = _availableDirection(initial);
    await tester.sendKeyEvent(_keyFor(direction));
    await tester.pump();

    expect(_currentGame(tester).movesMade, 1);
  });

  testWidgets('WASD keys also move the tiles', (tester) async {
    await tester.pumpWidget(_testApplication(_MemoryTutorialStore(seen: true)));
    await tester.pumpAndSettle();

    final direction = _availableDirection(_currentGame(tester));
    await tester.sendKeyEvent(_wasdKeyFor(direction));
    await tester.pump();

    expect(_currentGame(tester).movesMade, 1);
  });

  testWidgets('holding a key does not repeat a move', (tester) async {
    await tester.pumpWidget(_testApplication(_MemoryTutorialStore(seen: true)));
    await tester.pumpAndSettle();

    final key = _keyFor(_availableDirection(_currentGame(tester)));
    await tester.sendKeyDownEvent(key);
    await tester.sendKeyRepeatEvent(key);
    await tester.sendKeyUpEvent(key);
    await tester.pump();

    expect(_currentGame(tester).movesMade, 1);
  });

  testWidgets('one swipe produces one move', (tester) async {
    await tester.pumpWidget(_testApplication(_MemoryTutorialStore(seen: true)));
    await tester.pumpAndSettle();

    final direction = _availableDirection(_currentGame(tester));
    await tester.drag(
      find.byKey(const ValueKey('play_board')),
      _swipeFor(direction),
    );
    await tester.pump();

    expect(_currentGame(tester).movesMade, 1);
  });

  testWidgets('short swipes are ignored', (tester) async {
    await tester.pumpWidget(_testApplication(_MemoryTutorialStore(seen: true)));
    await tester.pumpAndSettle();

    await tester.drag(
      find.byKey(const ValueKey('play_board')),
      const Offset(8, 0),
    );
    await tester.pump();

    expect(_currentGame(tester).movesMade, 0);
  });

  testWidgets('the tutorial blocks gameplay until dismissed', (tester) async {
    final store = _MemoryTutorialStore();
    await tester.pumpWidget(_testApplication(store));
    await tester.pumpAndSettle();

    final direction = _availableDirection(_currentGame(tester));
    await tester.sendKeyEvent(_keyFor(direction));
    await tester.pump();
    expect(_currentGame(tester).movesMade, 0);

    await tester.tap(find.text('Got it!'));
    await tester.pumpAndSettle();
    await tester.sendKeyEvent(_keyFor(direction));
    await tester.pump();

    expect(_currentGame(tester).movesMade, 1);
  });
}
