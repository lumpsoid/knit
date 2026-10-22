import 'package:flutter/material.dart';
import 'package:knit/l10n/app_localizations.dart';

/// The backlinks count under a card bubble (§4.2/§4.4): "← 2", how many links
/// point *at* the card. Shown only when [count] > 0; tapping opens the
/// Connections page focused on that card. The card's own links out are its
/// chips (or its tile), so a link never reads twice on one card. A calm pill —
/// a read affordance, not a loud action. Takes primitives only (widgets.md §1).
class CardBacklinksBadge extends StatelessWidget {
  const CardBacklinksBadge({
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
    final label = l10n.collectionCardBacklinks(count);
    return Tooltip(
      message: label,
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.west, size: 14, color: theme.colorScheme.primary),
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
    );
  }
}
