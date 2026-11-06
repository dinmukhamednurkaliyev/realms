import 'package:flutter/material.dart';

import 'raw.dart';
import 'semantic.dart';

/// Shared light appearance, inspired by the existing building artwork.
final ThemeData lightTheme = _theme(
  ColorScheme.fromSeed(
    seedColor: leafGreen,
    surface: ivoryGreen,
    surfaceContainerHighest: paleGreen,
    primaryContainer: springGreen,
  ),
);

/// Shared dark appearance with muted green and earth colors.
final ThemeData darkTheme = _theme(
  ColorScheme.fromSeed(
    seedColor: sageGreen,
    brightness: Brightness.dark,
    surface: deepGreen,
    surfaceContainerHighest: mossGreen,
    primaryContainer: fernGreen,
  ),
);

ThemeData _theme(ColorScheme colors) => ThemeData(
  useMaterial3: true,
  colorScheme: colors,
  scaffoldBackgroundColor: colors.surface,
  extensions: [GameAppearance.fromScheme(colors)],
);
