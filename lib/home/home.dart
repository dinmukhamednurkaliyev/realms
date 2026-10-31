import 'package:flutter/material.dart';
import 'package:realms/app/localization/localization.dart';

/// The home screen, with navigation handled by the application.
final class HomeScreen extends StatelessWidget {
  /// Creates the home screen.
  const new({required this.onStartGame, super.key});

  /// Requests that the application open the game.
  final VoidCallback onStartGame;

  @override
  Widget build(BuildContext context) {
    final strings = Strings.of(context);
    final typography = Theme.of(context).textTheme;

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: SingleChildScrollView(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.castle_outlined, size: 88),
                    const SizedBox(height: 24),
                    Text(strings.appTitle, style: typography.displayMedium),
                    const SizedBox(height: 8),
                    Text(
                      strings.tagline,
                      style: typography.titleMedium,
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 48),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton(
                        onPressed: onStartGame,
                        child: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          child: Text(strings.startGame),
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
