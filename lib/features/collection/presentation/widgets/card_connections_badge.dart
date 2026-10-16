import 'package:flutter/material.dart';
import 'package:knit/l10n/app_localizations.dart';

/// The links-out count under a card bubble (§4.4). Shown only when [count] > 0;
/// tapping opens the Connections page focused on that card. A calm, left-aligned
/// pill that tucks just under the bubble — a read affordance, not a loud action.
/// Takes primitives only (widgets.md §1).
class CardConnectionsBadge extends StatelessWidget {
  const CardConnectionsBadge({
    super.key,
    required this.count,
    required this.onTap,
  });

  final int count;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);
    final label = l10n.collectionCardConnections(count);
    return Padding(
      // Left-inset to sit under the bubble (which starts 12px in), with a touch
      // more so the icon aligns near the bubble's text.
      padding: const EdgeInsets.only(left: 16, top: 2, bottom: 4),
      child: Tooltip(
        message: label,
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.hub_outlined,
                  size: 14,
                  color: theme.colorScheme.primary,
                ),
                const SizedBox(width: 4),
                Text(
                  '$count',
                  semanticsLabel: label,
                  style: theme.textTheme.labelMedium?.copyWith(
                    color: theme.colorScheme.primary,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
