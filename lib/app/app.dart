import 'package:flutter/material.dart';
import 'package:realms/game/game.dart' as game;
import 'package:realms/home/home.dart' as home;

import 'localization/localization.dart' as localization;
import 'theme.dart';

/// Configures the shared application appearance, localization, and home page.
final class Application extends StatelessWidget {
  /// Creates the application root.
  const new({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      onGenerateTitle: (context) => localization.Strings.of(context).appTitle,
      debugShowCheckedModeBanner: false,
      theme: lightTheme,
      darkTheme: darkTheme,
      localizationsDelegates: localization.Strings.localizationsDelegates,
      supportedLocales: localization.Strings.supportedLocales,
      home: Builder(
        builder: (context) => home.Screen(
          onStartGame: () {
            Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (context) => const game.PlayScreen(),
              ),
            );
          },
        ),
      ),
    );
  }
}
