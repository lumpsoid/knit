import 'package:flutter/material.dart';

/// How an emphasized card (§3.3) is drawn: the opposite of [SettledPalette]'s
/// recede — a bright warm-amber frame with a faint halo ring around the bubble.
abstract final class EmphasizedPalette {
  /// The frame's stroke width.
  static const double frameWidth = 2;

  /// How far the halo ring reaches past the bubble. Kept within the bubble's
  /// 4px row gap, so the neighbouring rows don't crop it.
  static const double haloWidth = 2;

  static const Color _amberLight = Color(0xFFFFA000);
  static const Color _amberDark = Color(0xFFFFC94D);

  /// The frame colour: a deeper amber on light pages, a brighter one on dark.
  static Color frame(Brightness brightness) =>
      brightness == Brightness.dark ? _amberDark : _amberLight;

  /// The halo around the bubble, [t] of the way in (0 = none, 1 = emphasized).
  /// A solid spread with no blur: a plain rounded rect, cheap on mobile.
  static List<BoxShadow> halo(Brightness brightness, double t) => [
    BoxShadow(
      color: frame(brightness).withValues(alpha: 0.25 * t),
      spreadRadius: haloWidth,
    ),
  ];
}
