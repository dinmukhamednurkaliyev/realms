import 'package:flutter/cupertino.dart' show CupertinoLocalizations;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:realms/app/app.dart';
import 'package:realms/app/audio/audio.dart';
import 'package:realms/app/localization/localization.dart';
import 'package:realms/game/game.dart';
import 'package:realms/home/home.dart';

void main() {
  test('generated catalogs preserve both languages', () async {
    final english = await AppLocalization.delegate.load(const Locale('en'));
    final russian = await AppLocalization.delegate.load(const Locale('ru'));

    expect(english.home.startGame, 'Start game');
    expect(russian.home.startGame, 'Начать игру');
    expect(english.game.score(points: 1250), '1250');
    expect(russian.game.score(points: 1250), '1250');
    expect(english.game.howToPlayKeyboard, 'Keyboard: arrow keys or WASD.');
    expect(russian.game.howToPlayKeyboard, 'Клавиатура: стрелки или WASD.');
    expect(AppLocalization.supportedLocales, [
      const Locale('en'),
      const Locale('ru'),
    ]);
  });

  testWidgets('defaults to the device locale and resolves regional variants', (
    tester,
  ) async {
    tester.platformDispatcher.localesTestValue = [const Locale('ru', 'RU')];
    addTearDown(tester.platformDispatcher.clearLocalesTestValue);

    final preference = ValueNotifier<Locale?>(null);
    addTearDown(preference.dispose);
    await tester.pumpWidget(
      RealmsApp(localePreference: preference, audio: const _SilentAudio()),
    );
    await tester.pumpAndSettle();

    expect(find.text('Начать игру'), findsOneWidget);
    final context = tester.element(find.byType(HomeScreen));
    expect(AppLocalization.of(context).localeName, 'ru');
    expect(MaterialLocalizations.of(context).backButtonTooltip, 'Назад');
    expect(CupertinoLocalizations.of(context).backButtonLabel, 'Назад');
  });

  testWidgets('uses English when the device locale is unsupported', (
    tester,
  ) async {
    tester.platformDispatcher.localesTestValue = [const Locale('fr')];
    addTearDown(tester.platformDispatcher.clearLocalesTestValue);

    final preference = ValueNotifier<Locale?>(null);
    addTearDown(preference.dispose);
    await tester.pumpWidget(
      RealmsApp(localePreference: preference, audio: const _SilentAudio()),
    );
    await tester.pumpAndSettle();

    expect(find.text('Start game'), findsOneWidget);
    expect(
      Localizations.localeOf(tester.element(find.byType(HomeScreen))),
      const Locale('en'),
    );
  });

  testWidgets(
    'locale changes rebuild dependent widgets and preserve the route',
    (tester) async {
      final preference = ValueNotifier<Locale?>(null);
      addTearDown(preference.dispose);
      await tester.pumpWidget(
        RealmsApp(localePreference: preference, audio: const _SilentAudio()),
      );

      await tester.tap(find.text('Start game'));
      await tester.pumpAndSettle();
      final playElement = tester.element(find.byType(PlayScreen));
      final boardText = find.descendant(
        of: find.byKey(const ValueKey('play_board')),
        matching: find.byType(Text),
      );
      final tiles = tester
          .widgetList<Text>(boardText)
          .map((text) => text.data)
          .toList();

      preference.value = const Locale('ru');
      await tester.pumpAndSettle();

      expect(find.text('Классический режим'), findsOneWidget);
      expect(find.text('СЧЁТ'), findsOneWidget);
      expect(tester.element(find.byType(PlayScreen)), same(playElement));
      expect(
        tester.widgetList<Text>(boardText).map((text) => text.data),
        tiles,
      );

      await tester.tap(find.byType(BackButton));
      await tester.pumpAndSettle();
      expect(find.text('Начать игру'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('explicit preference overrides the device and null restores it', (
    tester,
  ) async {
    tester.platformDispatcher.localesTestValue = [const Locale('ru')];
    addTearDown(tester.platformDispatcher.clearLocalesTestValue);
    final preference = ValueNotifier<Locale?>(null);
    addTearDown(preference.dispose);
    await tester.pumpWidget(
      RealmsApp(localePreference: preference, audio: const _SilentAudio()),
    );
    await tester.pumpAndSettle();

    preference.value = const Locale('en');
    await tester.pumpAndSettle();
    expect(find.text('Start game'), findsOneWidget);

    preference.value = null;
    await tester.pumpAndSettle();
    expect(find.text('Начать игру'), findsOneWidget);

    preference.value = const Locale('fr');
    await tester.pumpAndSettle();
    expect(find.text('Start game'), findsOneWidget);
  });

  testWidgets('AppLocalization.of subscribes without rebuilding its parent', (
    tester,
  ) async {
    final preference = ValueNotifier<Locale>(const Locale('en'));
    addTearDown(preference.dispose);
    const child = _LocalizedText();
    await tester.pumpWidget(
      ValueListenableBuilder<Locale>(
        valueListenable: preference,
        builder: (context, locale, _) => MaterialApp(
          locale: locale,
          localizationsDelegates: AppLocalization.localizationsDelegates,
          supportedLocales: AppLocalization.supportedLocales,
          home: child,
        ),
      ),
    );
    expect(find.text('Start game'), findsOneWidget);

    preference.value = const Locale('ru');
    await tester.pumpAndSettle();
    expect(find.text('Начать игру'), findsOneWidget);
  });

  testWidgets('appearance remains reactive to device brightness', (
    tester,
  ) async {
    tester.platformDispatcher.platformBrightnessTestValue = Brightness.light;
    addTearDown(tester.platformDispatcher.clearPlatformBrightnessTestValue);
    final preference = ValueNotifier<Locale?>(null);
    addTearDown(preference.dispose);
    await tester.pumpWidget(
      RealmsApp(localePreference: preference, audio: const _SilentAudio()),
    );
    await tester.pumpAndSettle();
    final context = tester.element(find.byType(HomeScreen));
    final light = Theme.of(context);
    expect(light.brightness, Brightness.light);

    tester.platformDispatcher.platformBrightnessTestValue = Brightness.dark;
    await tester.pumpAndSettle();
    final dark = Theme.of(context);
    expect(dark.brightness, Brightness.dark);
    expect(dark.colorScheme.primary, isNot(light.colorScheme.primary));
  });
}

class _LocalizedText extends StatelessWidget {
  const new();

  @override
  Widget build(BuildContext context) =>
      Text(AppLocalization.of(context).home.startGame);
}

final class _SilentAudio implements AudioPlayback {
  const new();
  @override
  Future<void> initialize() async {}
  @override
  void play(SoundEffect effect, {double volume = 1}) {}
}
