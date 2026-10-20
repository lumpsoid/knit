import 'package:flutter/material.dart';

/// How a settled card (§3.3) is drawn: it recedes toward the page, loses its
/// colour and fades, with barely visible roots. Neutral, no tint, so it never
/// competes with the live cards (the "Ghost" tuning).
abstract final class SettledPalette {
  /// How far the bubble blends from its live fill toward the page surface.
  static const double recede = 0.8;

  /// How much a settled card's content fades (1 = fully faded).
  static const double contentFade = 0.55;

  /// How much colour a settled card's content loses (1 = greyscale).
  static const double desaturation = 1;

  static const double _rootsAlpha = 0.04;

  /// The bubble fill once settled: the live [base] fill receded toward the
  /// page surface.
  static Color background(ColorScheme scheme, Color base) =>
      Color.lerp(base, scheme.surface, recede)!;

  /// The roots' stroke colour.
  static Color roots(ColorScheme scheme) =>
      scheme.onSurfaceVariant.withValues(alpha: _rootsAlpha);

  /// A settled card's one-line preview text elsewhere (the home row).
  static Color previewText(ColorScheme scheme) =>
      scheme.onSurfaceVariant.withValues(alpha: 1 - contentFade);

  /// A filter that drains colour from a settled card's content, [t] of the
  /// way (0 = untouched, 1 = settled).
  static ColorFilter desaturate(double t) {
    final s = 1 - desaturation * t;
    // Rec. 709 luma weights.
    const r = 0.2126, g = 0.7152, b = 0.0722;
    return ColorFilter.matrix([
      r + (1 - r) * s, g - g * s, b - b * s, 0, 0, //
      r - r * s, g + (1 - g) * s, b - b * s, 0, 0, //
      r - r * s, g - g * s, b + (1 - b) * s, 0, 0, //
      0, 0, 0, 1, 0,
    ]);
  }
}
