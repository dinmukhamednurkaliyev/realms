import 'package:flutter/material.dart';
import 'package:realms/app/appearance/appearance.dart';
import 'package:realms/app/localization/localization.dart';
import 'package:realms/game/game.dart';
import 'package:realms/home/home.dart';

/// Configures the shared application appearance, localization, and home page.
final class RealmsApp extends StatelessWidget {
  /// Creates the application root.
  const new({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      onGenerateTitle: (context) => Strings.of(context).appTitle,
      debugShowCheckedModeBanner: false,
      theme: lightTheme,
      darkTheme: darkTheme,
      localizationsDelegates: Strings.localizationsDelegates,
      supportedLocales: Strings.supportedLocales,
      home: Builder(
        builder: (context) => HomeScreen(
          onStartGame: () {
            Navigator.of(context).push(
              MaterialPageRoute<void>(builder: (context) => const PlayScreen()),
            );
          },
        ),
      ),
    );
  }
}
