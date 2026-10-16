import 'package:flutter/material.dart';

/// A feed card's entrance/exit, driven by its [SliverAnimatedList] animation:
/// the row opens its space (nudging the cards above it up), while the card
/// fades in and rises slightly. Played in reverse when a card is removed. Initial
/// items get a completed animation, so they render as-is.
class CardEntrance extends StatelessWidget {
  const CardEntrance({super.key, required this.animation, required this.child});

  final Animation<double> animation;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final curved = CurvedAnimation(
      parent: animation,
      curve: Curves.easeOutCubic,
      reverseCurve: Curves.easeInCubic,
    );
    return SizeTransition(
      sizeFactor: curved,
      alignment: Alignment.topCenter,
      child: FadeTransition(
        opacity: curved,
        child: SlideTransition(
          position: Tween(
            begin: const Offset(0, 0.25),
            end: Offset.zero,
          ).animate(curved),
          child: child,
        ),
      ),
    );
  }
}
