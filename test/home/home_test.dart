import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:realms/app/app.dart';
import 'package:realms/game/game.dart';

void main() {
  group('Home', () {
    testWidgets('opens Classic from Home', (tester) async {
      await tester.pumpWidget(const ProviderScope(child: RealmsApp()));

      expect(find.text('REALMS'), findsOneWidget);
      expect(find.text('Start game'), findsOneWidget);

      await tester.tap(find.text('Start game'));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.byType(PlayScreen), findsOneWidget);
      expect(find.text('Classic'), findsOneWidget);
      expect(find.text('SCORE'), findsOneWidget);
    });

    testWidgets('returns to Home from Classic', (tester) async {
      await tester.pumpWidget(const ProviderScope(child: RealmsApp()));

      await tester.tap(find.text('Start game'));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.byType(PlayScreen), findsOneWidget);

      final backButton = find.byType(BackButton);

      expect(backButton, findsOneWidget);

      await tester.tap(backButton);
      await tester.pumpAndSettle();

      expect(find.byType(PlayScreen), findsNothing);
      expect(find.text('Start game'), findsOneWidget);
    });
  });
}
