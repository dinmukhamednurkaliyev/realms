import 'package:flutter/material.dart';

/// Shared light appearance, inspired by the forest building artwork.
final ThemeData lightTheme = ThemeData(
  useMaterial3: true,
  colorScheme: ColorScheme.fromSeed(
    seedColor: const Color(0xFF597D35),
    surface: const Color(0xFFF0F3E5),
    surfaceContainerHighest: const Color(0xFFD9E4C5),
    primaryContainer: const Color(0xFFC6DA9F),
  ),
  scaffoldBackgroundColor: const Color(0xFFF0F3E5),
);

/// Shared dark appearance with muted forest and earth colors.
final ThemeData darkTheme = ThemeData(
  useMaterial3: true,
  colorScheme: ColorScheme.fromSeed(
    seedColor: const Color(0xFFA0C875),
    brightness: Brightness.dark,
    surface: const Color(0xFF1D281D),
    surfaceContainerHighest: const Color(0xFF374A32),
    primaryContainer: const Color(0xFF436340),
  ),
  scaffoldBackgroundColor: const Color(0xFF1D281D),
);
