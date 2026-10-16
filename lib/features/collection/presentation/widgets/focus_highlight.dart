import 'package:flutter/material.dart';

/// The tint behind a revealed card (e.g. opened from a search hit): shown at
/// once, then faded out when [active] turns false.
class FocusHighlight extends StatelessWidget {
  const FocusHighlight({super.key, required this.active, required this.child});

  final bool active;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final tint = Theme.of(context).colorScheme.primaryContainer;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 600),
      decoration: BoxDecoration(
        color: tint.withValues(alpha: active ? 0.7 : 0),
        borderRadius: BorderRadius.circular(12),
      ),
      child: child,
    );
  }
}
