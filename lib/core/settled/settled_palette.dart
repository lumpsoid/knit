import 'package:flutter/material.dart';

/// The autumn palette a settled card (§3.3) is drawn in: a warm amber wash
/// over the bubble, faint brown roots, and a quieter foreground. Tuned per
/// brightness so it reads as "faded" in both themes.
abstract final class SettledPalette {
  static const Color _amber = Color(0xFFE8892C);
  static const Color _rootLight = Color(0xFF8A4B14);
  static const Color _rootDark = Color(0xFFE3A55E);

  /// How much a settled card's content fades (1 = fully faded).
  static const double contentFade = 0.3;

  /// The bubble fill once settled, warmed from the live [base] fill.
  static Color background(ColorScheme scheme, Color base) => Color.alphaBlend(
    _amber.withValues(alpha: _isDark(scheme) ? 0.14 : 0.2),
    base,
  );

  /// The roots' stroke colour.
  static Color roots(ColorScheme scheme) => _isDark(scheme)
      ? _rootDark.withValues(alpha: 0.2)
      : _rootLight.withValues(alpha: 0.17);

  /// A settled card's one-line preview text elsewhere (the home row): a
  /// muted, slightly warm tone.
  static Color previewText(ColorScheme scheme) =>
      Color.lerp(scheme.onSurfaceVariant, _amber, 0.3)!.withValues(alpha: 0.65);

  static bool _isDark(ColorScheme scheme) =>
      scheme.brightness == Brightness.dark;
}
