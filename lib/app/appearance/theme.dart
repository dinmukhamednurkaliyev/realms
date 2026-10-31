import 'package:flutter/material.dart';

/// Shared light appearance; screens inherit it through Theme.of(context).
final ThemeData lightTheme = ThemeData(
  useMaterial3: true,
  colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF81684A)),
  scaffoldBackgroundColor: const Color(0xFFF5F0E7),
);

/// Shared dark appearance; screens inherit it through Theme.of(context).
final ThemeData darkTheme = ThemeData(
  useMaterial3: true,
  colorScheme: ColorScheme.fromSeed(
    seedColor: const Color(0xFFC19B68),
    brightness: Brightness.dark,
  ),
  scaffoldBackgroundColor: const Color(0xFF191A17),
);
