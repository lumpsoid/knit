import 'package:flutter/material.dart';

/// How an emphasized card (§3.3) is drawn: the opposite of [SettledPalette]'s
/// recede — a bright warm-amber frame with a soft glow around the bubble.
abstract final class EmphasizedPalette {
  /// The frame's stroke width.
  static const double frameWidth = 2;

  /// The glow's blur radius.
  static const double glowBlur = 14;

  static const Color _amberLight = Color(0xFFFFA000);
  static const Color _amberDark = Color(0xFFFFC94D);

  /// The frame colour: a deeper amber on light pages, a brighter one on dark.
  static Color frame(Brightness brightness) =>
      brightness == Brightness.dark ? _amberDark : _amberLight;

  /// The halo around the bubble, [t] of the way in (0 = none, 1 = emphasized).
  static List<BoxShadow> glow(Brightness brightness, double t) => [
    BoxShadow(
      color: frame(brightness).withValues(alpha: 0.45 * t),
      blurRadius: glowBlur,
      spreadRadius: 1,
    ),
  ];
}
