import 'package:flutter/material.dart';

/// A feed row in multi-select mode: tinted with a check mark when [selected];
/// a tap anywhere on it calls [onTap] (toggle).
class SelectableCardRow extends StatelessWidget {
  const SelectableCardRow({
    super.key,
    required this.selected,
    required this.onTap,
    required this.child,
  });

  final bool selected;
  final VoidCallback onTap;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: ColoredBox(
        color: selected
            ? scheme.primaryContainer.withValues(alpha: 0.5)
            : Colors.transparent,
        child: Stack(
          children: [
            child,
            // The bubble leaves a right-hand gutter; the check sits in it.
            Positioned(
              top: 0,
              bottom: 0,
              right: 20,
              child: Center(
                child: Icon(
                  selected ? Icons.check_circle : Icons.radio_button_unchecked,
                  color: selected ? scheme.primary : scheme.outline,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
