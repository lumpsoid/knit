import 'package:flutter/material.dart';
import 'package:knit/l10n/app_localizations.dart';

/// The Archive entry at the top of Home (§3.4): hidden until the user pulls
/// the list down, then a row that opens the Archive page. Its height is fixed
/// ([height]) so the page can scroll it out of view and drop it without the
/// rows below jumping.
class TimelineArchiveRow extends StatelessWidget {
  const TimelineArchiveRow({
    super.key,
    required this.count,
    required this.onTap,
  });

  /// The row's fixed height, its bottom divider included.
  static const double height = 64;

  /// How many collections are archived.
  final int count;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);
    final muted = theme.colorScheme.onSurfaceVariant;
    return SizedBox(
      height: height,
      child: Column(
        children: [
          Expanded(
            child: InkWell(
              onTap: onTap,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Row(
                  children: [
                    CircleAvatar(
                      backgroundColor:
                          theme.colorScheme.surfaceContainerHighest,
                      child: Icon(Icons.archive_outlined, color: muted),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Text(
                        l10n.timelineArchiveRow,
                        style: theme.textTheme.bodyLarge,
                      ),
                    ),
                    Text(
                      l10n.timelineArchiveCount(count),
                      style: theme.textTheme.labelSmall?.copyWith(color: muted),
                    ),
                  ],
                ),
              ),
            ),
          ),
          const Divider(height: 1),
        ],
      ),
    );
  }
}
