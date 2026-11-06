import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:realms/app/appearance/appearance.dart';
import 'package:realms/app/appearance/raw.dart'
    show mossGreen, paleGreen, radiusMedium;

void main() {
  test('keeps the existing palette, spacing and typography', () {
    final expectedLight = ColorScheme.fromSeed(
      seedColor: const Color(0xFF597D35),
      surface: const Color(0xFFF0F3E5),
      surfaceContainerHighest: const Color(0xFFD9E4C5),
      primaryContainer: const Color(0xFFC6DA9F),
    );
    final expectedDark = ColorScheme.fromSeed(
      seedColor: const Color(0xFFA0C875),
      brightness: Brightness.dark,
      surface: const Color(0xFF1D281D),
      surfaceContainerHighest: const Color(0xFF374A32),
      primaryContainer: const Color(0xFF436340),
    );
    expect(lightTheme.colorScheme, expectedLight);
    expect(darkTheme.colorScheme, expectedDark);
    expect(
      lightTheme.textTheme,
      ThemeData(colorScheme: expectedLight).textTheme,
    );
    expect(darkTheme.textTheme, ThemeData(colorScheme: expectedDark).textTheme);
    expect(
      [spaceSmall, spaceMedium, spaceRegular, spaceLarge, spaceExtraLarge],
      [8, 16, 20, 24, 48],
    );
    expect(radiusMedium, 10);
  });

  for (final theme in [lightTheme, darkTheme]) {
    test('defines all game roles for ${theme.brightness.name}', () {
      final roles = theme.extension<GameAppearance>()!;
      expect(roles.emptyCell, theme.colorScheme.surfaceContainerHighest);
      expect(roles.fallbackTile, theme.colorScheme.primaryContainer);
      expect(roles.tutorialScrim, const Color(0x99000000));
      expect(roles.cellRadius, radiusMedium);
      expect(roles.cellSpacing, spaceSmall);
      expect(theme.scaffoldBackgroundColor, theme.colorScheme.surface);
    });

    test(
      'preserves readable score and fallback text in ${theme.brightness.name}',
      () {
        final foreground = theme.colorScheme.onSurface;
        for (final background in [
          theme.scaffoldBackgroundColor,
          theme.extension<GameAppearance>()!.fallbackTile,
        ]) {
          final first = foreground.computeLuminance();
          final second = background.computeLuminance();
          final lighter = first > second ? first : second;
          final darker = first < second ? first : second;
          expect((lighter + 0.05) / (darker + 0.05), greaterThanOrEqualTo(4.5));
        }
      },
    );
  }

  test('copyWith retains unspecified roles without mutating the original', () {
    final original = lightTheme.extension<GameAppearance>()!;
    final copy = original.copyWith(emptyCell: Colors.red, cellSpacing: 12);
    expect(copy.emptyCell, Colors.red);
    expect(copy.cellSpacing, 12);
    expect(copy.fallbackTile, original.fallbackTile);
    expect(copy.tutorialScrim, original.tutorialScrim);
    expect(copy.cellRadius, original.cellRadius);
    expect(original.emptyCell, paleGreen);
    expect(original.cellSpacing, 8);
  });

  test('lerp covers every color and geometry role, including endpoints', () {
    final first = lightTheme.extension<GameAppearance>()!;
    final second = darkTheme.extension<GameAppearance>()!.copyWith(
      tutorialScrim: Colors.transparent,
      cellRadius: 20,
      cellSpacing: 16,
    );
    final middle = first.lerp(second, 0.5);
    expect(
      middle.emptyCell,
      Color.lerp(first.emptyCell, second.emptyCell, 0.5),
    );
    expect(
      middle.fallbackTile,
      Color.lerp(first.fallbackTile, second.fallbackTile, 0.5),
    );
    expect(
      middle.tutorialScrim,
      Color.lerp(first.tutorialScrim, second.tutorialScrim, 0.5),
    );
    expect(middle.cellRadius, 15);
    expect(middle.cellSpacing, 12);
    expect(first.lerp(second, 0).emptyCell, first.emptyCell);
    expect(first.lerp(second, 1).cellRadius, second.cellRadius);
    expect(first.lerp(null, 0.5), same(first));
    expect(
      ThemeData.lerp(
        lightTheme,
        darkTheme,
        0.5,
      ).extension<GameAppearance>()!.emptyCell,
      Color.lerp(first.emptyCell, second.emptyCell, 0.5),
    );
  });

  testWidgets('context consumers update across theme changes', (tester) async {
    final dark = ValueNotifier<bool>(false);
    addTearDown(dark.dispose);
    await tester.pumpWidget(
      ValueListenableBuilder<bool>(
        valueListenable: dark,
        builder: (context, value, child) => MaterialApp(
          theme: value ? darkTheme : lightTheme,
          home: const _SemanticCell(),
        ),
      ),
    );
    expect(
      tester.widget<ColoredBox>(find.byKey(const ValueKey('cell'))).color,
      paleGreen,
    );
    dark.value = true;
    await tester.pumpAndSettle();
    expect(
      tester.widget<ColoredBox>(find.byKey(const ValueKey('cell'))).color,
      mossGreen,
    );
  });

  testWidgets('standard Material hosts receive compatible semantic defaults', (
    tester,
  ) async {
    await tester.pumpWidget(const MaterialApp(home: _SemanticCell()));
    final context = tester.element(find.byType(_SemanticCell));
    expect(
      GameAppearance.of(context).emptyCell,
      Theme.of(context).colorScheme.surfaceContainerHighest,
    );
  });
}

final class _SemanticCell extends StatelessWidget {
  const new();
  @override
  Widget build(BuildContext context) => ColoredBox(
    key: const ValueKey('cell'),
    color: GameAppearance.of(context).emptyCell,
  );
}
