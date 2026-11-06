import 'dart:ui' show lerpDouble;

import 'package:flutter/material.dart';

import 'raw.dart';

/// Game presentation roles, independent of tile levels, artwork and game rules.
@immutable
final class GameAppearance extends ThemeExtension<GameAppearance> {
  /// Creates a complete set of roles for a Flutter theme.
  const new({
    required this.emptyCell,
    required this.fallbackTile,
    required this.tutorialScrim,
    required this.cellRadius,
    required this.cellSpacing,
  });

  /// Preserves the existing Material color mappings and board geometry.
  factory fromScheme(ColorScheme colors) => GameAppearance(
    emptyCell: colors.surfaceContainerHighest,
    fallbackTile: colors.primaryContainer,
    tutorialScrim: black60,
    cellRadius: radiusMedium,
    cellSpacing: spaceSmall,
  );

  /// Resolves roles reactively, also supporting a standard Material theme.
  factory of(BuildContext context) {
    final theme = Theme.of(context);
    return theme.extension<GameAppearance>() ??
        GameAppearance.fromScheme(theme.colorScheme);
  }

  /// Background visible behind tile artwork and in unoccupied cells.
  final Color emptyCell;

  /// Background for levels whose artwork is unavailable.
  final Color fallbackTile;

  /// Dimming behind the tutorial card.
  final Color tutorialScrim;

  /// Board cell corner radius in logical pixels.
  final double cellRadius;

  /// Gap between cells in logical pixels.
  final double cellSpacing;

  @override
  GameAppearance copyWith({
    Color? emptyCell,
    Color? fallbackTile,
    Color? tutorialScrim,
    double? cellRadius,
    double? cellSpacing,
  }) => GameAppearance(
    emptyCell: emptyCell ?? this.emptyCell,
    fallbackTile: fallbackTile ?? this.fallbackTile,
    tutorialScrim: tutorialScrim ?? this.tutorialScrim,
    cellRadius: cellRadius ?? this.cellRadius,
    cellSpacing: cellSpacing ?? this.cellSpacing,
  );

  @override
  GameAppearance lerp(covariant GameAppearance? other, double t) {
    if (other == null) return this;
    return GameAppearance(
      emptyCell: Color.lerp(emptyCell, other.emptyCell, t)!,
      fallbackTile: Color.lerp(fallbackTile, other.fallbackTile, t)!,
      tutorialScrim: Color.lerp(tutorialScrim, other.tutorialScrim, t)!,
      cellRadius: lerpDouble(cellRadius, other.cellRadius, t)!,
      cellSpacing: lerpDouble(cellSpacing, other.cellSpacing, t)!,
    );
  }
}
