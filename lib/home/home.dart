import 'package:flutter/material.dart';
import 'package:realms/app/appearance/appearance.dart';
import 'package:realms/app/localization/localization.dart';

/// The home screen, with navigation handled by the application.
final class HomeScreen extends StatelessWidget {
  /// Creates the home screen.
  const new({required this.onStartGame, super.key});

  /// Requests that the application open the game.
  final VoidCallback onStartGame;

  @override
  Widget build(BuildContext context) {
    final localization = AppLocalization.of(context);
    final typography = Theme.of(context).textTheme;

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: SingleChildScrollView(
              child: Padding(
                padding: const EdgeInsets.all(spaceLarge),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.castle_outlined, size: 88),
                    const SizedBox(height: spaceLarge),
                    Text(
                      localization.appTitle,
                      style: typography.displayMedium,
                    ),
                    const SizedBox(height: spaceSmall),
                    Text(
                      localization.home.tagline,
                      style: typography.titleMedium,
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: spaceExtraLarge),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton(
                        onPressed: onStartGame,
                        child: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          child: Text(localization.home.startGame),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
