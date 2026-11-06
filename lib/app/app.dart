import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:realms/app/appearance/appearance.dart';
import 'package:realms/app/audio/audio.dart';
import 'package:realms/app/localization/localization.dart';
import 'package:realms/game/game.dart';
import 'package:realms/home/home.dart';

/// Configures the shared application appearance, localization, and home page.
final class RealmsApp extends StatefulWidget {
  /// Creates the application root.
  const new({this.localePreference, this.audio, super.key});

  /// Null follows device locales. The caller owns any supplied listenable.
  final ValueListenable<Locale?>? localePreference;

  /// Optional shared playback owned by the caller for the application lifetime.
  final AudioPlayback? audio;

  @override
  State<RealmsApp> createState() => _RealmsAppState();
}

final class _RealmsAppState extends State<RealmsApp> {
  final _deviceLocale = ValueNotifier<Locale?>(null);
  final _audio = AppAudio();

  @override
  void dispose() {
    unawaited(_audio.dispose());
    _deviceLocale.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<Locale?>(
      valueListenable: widget.localePreference ?? _deviceLocale,
      builder: (context, locale, child) => MaterialApp(
        onGenerateTitle: (context) => AppLocalization.of(context).appTitle,
        debugShowCheckedModeBanner: false,
        theme: lightTheme,
        darkTheme: darkTheme,
        locale: locale,
        localizationsDelegates: AppLocalization.localizationsDelegates,
        supportedLocales: AppLocalization.supportedLocales,
        home: Builder(
          builder: (context) => HomeScreen(
            onStartGame: () {
              Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (context) =>
                      PlayScreen(audio: widget.audio ?? _audio),
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}
