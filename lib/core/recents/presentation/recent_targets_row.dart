import 'package:flutter/material.dart';
import 'package:knit/l10n/app_localizations.dart';

/// A picker's "Recent" row (§4.2/§4.4): a small heading over one chip per
/// recently used collection, most recent first. Takes the chips' [labels]
/// (already display-ready) and reports a tap by its index through
/// [onSelected]. The indexes in [checked] show a ✓ instead of the history
/// icon. Builds nothing when [labels] is empty.
class RecentTargetsRow extends StatelessWidget {
  const RecentTargetsRow({
    super.key,
    required this.labels,
    required this.onSelected,
    this.checked = const {},
  });

  final List<String> labels;
  final Set<int> checked;
  final ValueChanged<int> onSelected;

  @override
  Widget build(BuildContext context) {
    if (labels.isEmpty) return const SizedBox.shrink();
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            AppLocalizations.of(context).pickerRecent,
            style: theme.textTheme.labelMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 6),
          Wrap(
            spacing: 8,
            runSpacing: 4,
            children: [
              for (var i = 0; i < labels.length; i++)
                ActionChip(
                  avatar: Icon(
                    checked.contains(i) ? Icons.check : Icons.history,
                    size: 18,
                  ),
                  label: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 160),
                    child: Text(
                      labels[i],
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  onPressed: () => onSelected(i),
                ),
            ],
          ),
        ],
      ),
    );
  }
}
