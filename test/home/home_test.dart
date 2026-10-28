import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:realms/app/app.dart' as app;

void main() {
  testWidgets('opens Classic from the home screen', (tester) async {
    await tester.pumpWidget(const app.Application());

    expect(find.text('REALMS'), findsOneWidget);
    expect(find.text('Start game'), findsOneWidget);

    await tester.tap(find.text('Start game'));
    await tester.pumpAndSettle();

    expect(find.text('Classic'), findsOneWidget);
    expect(find.text('SCORE'), findsOneWidget);
    expect(find.byKey(const ValueKey('board_cell_0')), findsOneWidget);
  });

  testWidgets('returns to Home from Classic', (tester) async {
    await tester.pumpWidget(const app.Application());

    await tester.tap(find.text('Start game'));
    await tester.pumpAndSettle();

    await tester.pageBack();
    await tester.pumpAndSettle();

    expect(find.text('Start game'), findsOneWidget);
  });
}
