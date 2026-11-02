// GENERATED CODE - DO NOT MODIFY BY HAND.
// Generator: scripts/resources.dart. Manual edits will be overwritten.
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

/// Typed messages resolved for the active locale.
final class AppLocalization {
  const new _(this.localeName);

  /// Resolves previews and regional locales using Flutter's fallback rules.
  factory forLocale(Locale locale) => AppLocalization._(
    basicLocaleListResolution([locale], supportedLocales).toString(),
  );

  /// The resolved supported locale identifier.
  final String localeName;

  /// Registers this widget as dependent on the active language.
  static AppLocalization of(BuildContext context) =>
      Localizations.of<AppLocalization>(context, AppLocalization)!;

  /// Loads application messages synchronously from the compiled catalogs.
  static const LocalizationsDelegate<AppLocalization> delegate =
      _AppLocalizationDelegate();

  /// Preserves Flutter's Material, Cupertino and accessibility translations.
  static const localizationsDelegates = <LocalizationsDelegate<dynamic>>[
    delegate,
    GlobalMaterialLocalizations.delegate,
    GlobalCupertinoLocalizations.delegate,
    GlobalWidgetsLocalizations.delegate,
  ];

  /// The fallback comes first for Flutter's unsupported-locale resolution.
  static const supportedLocales = <Locale>[
    Locale.fromSubtags(languageCode: 'en'),
    Locale.fromSubtags(languageCode: 'ru'),
  ];

  /// Messages in the game catalog group.
  AppGameMessages get game => AppGameMessages._(localeName);

  /// Messages in the home catalog group.
  AppHomeMessages get home => AppHomeMessages._(localeName);

  /// Catalog message: appTitle.
  String get appTitle => switch (localeName) {
    'ru' => 'REALMS',
    _ => 'REALMS',
  };
}

/// Typed messages resolved for the active locale.
final class AppGameMessages {
  const new _(this.localeName);

  /// The resolved supported locale identifier.
  final String localeName;

  /// Catalog message: game.classicMode.
  String get classicMode => switch (localeName) {
    'ru' => 'Классический режим',
    _ => 'Classic',
  };

  /// Catalog message: game.gameOver.
  String get gameOver => switch (localeName) {
    'ru' => 'Ходов больше нет',
    _ => 'No moves left',
  };

  /// Catalog message: game.gotIt.
  String get gotIt => switch (localeName) {
    'ru' => 'Понятно',
    _ => 'Got it!',
  };

  /// Catalog message: game.howToPlayDescription.
  String get howToPlayDescription => switch (localeName) {
    'ru' =>
      'Проводите пальцем по полю, чтобы перемещать '
          'здания. Объединяйте одинаковые здания, чтобы '
          'развивать их.',
    _ =>
      'Swipe on the board to move the buildings. '
          'Combine identical buildings to evolve them.',
  };

  /// Catalog message: game.howToPlayKeyboard.
  String get howToPlayKeyboard => switch (localeName) {
    'ru' => 'Клавиатура: стрелки или WASD.',
    _ => 'Keyboard: arrow keys or WASD.',
  };

  /// Catalog message: game.howToPlayTitle.
  String get howToPlayTitle => switch (localeName) {
    'ru' => 'Как играть',
    _ => 'How to Play',
  };

  /// Catalog message: game.moveDown.
  String get moveDown => switch (localeName) {
    'ru' => 'Вниз',
    _ => 'Move down',
  };

  /// Catalog message: game.moveHint.
  String get moveHint => switch (localeName) {
    'ru' => 'Перемещайте плитки стрелками.',
    _ => 'Move tiles using the arrows.',
  };

  /// Catalog message: game.moveLeft.
  String get moveLeft => switch (localeName) {
    'ru' => 'Влево',
    _ => 'Move left',
  };

  /// Catalog message: game.moveRight.
  String get moveRight => switch (localeName) {
    'ru' => 'Вправо',
    _ => 'Move right',
  };

  /// Catalog message: game.moveUp.
  String get moveUp => switch (localeName) {
    'ru' => 'Вверх',
    _ => 'Move up',
  };

  /// Catalog message: game.newGame.
  String get newGame => switch (localeName) {
    'ru' => 'Новая игра',
    _ => 'New game',
  };

  /// Catalog message: game.score.
  String score({required int points}) => switch (localeName) {
    'ru' => points.toString(),
    _ => points.toString(),
  };

  /// Catalog message: game.scoreLabel.
  String get scoreLabel => switch (localeName) {
    'ru' => 'СЧЁТ',
    _ => 'SCORE',
  };

  /// Catalog message: game.youWon.
  String get youWon => switch (localeName) {
    'ru' => 'Победа!',
    _ => 'You won!',
  };
}

/// Typed messages resolved for the active locale.
final class AppHomeMessages {
  const new _(this.localeName);

  /// The resolved supported locale identifier.
  final String localeName;

  /// Catalog message: home.startGame.
  String get startGame => switch (localeName) {
    'ru' => 'Начать игру',
    _ => 'Start game',
  };

  /// Catalog message: home.tagline.
  String get tagline => switch (localeName) {
    'ru' => 'Строй. Объединяй. Развивай.',
    _ => 'Build. Merge. Evolve.',
  };
}

final class _AppLocalizationDelegate
    extends LocalizationsDelegate<AppLocalization> {
  const new();
  @override
  bool isSupported(Locale locale) => AppLocalization.supportedLocales.any(
    (supported) => supported.languageCode == locale.languageCode,
  );
  @override
  Future<AppLocalization> load(Locale locale) =>
      SynchronousFuture(AppLocalization.forLocale(locale));
  @override
  bool shouldReload(_AppLocalizationDelegate old) => false;
}
