import 'package:flutter/material.dart';
import 'package:knit/features/collection_present/domain/present_models.dart';
import 'package:knit/l10n/app_localizations.dart';

/// A card's live links on a slide (§4.9): "See also", then a chip per link —
/// a tap follows it (another collection is presented on top).
class SeeAlsoChips extends StatelessWidget {
  const SeeAlsoChips({super.key, required this.links, required this.onOpen});

  final List<PresentLink> links;
  final ValueChanged<PresentLink> onOpen;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Wrap(
        spacing: 8,
        runSpacing: 4,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          Text(
            l10n.presentSeeAlso,
            style: theme.textTheme.labelLarge?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          for (final link in links)
            ActionChip(
              avatar: Icon(
                link.kind == PresentLinkKind.collection
                    ? Icons.folder_outlined
                    : Icons.notes,
                size: 18,
              ),
              label: Text(
                link.label.isEmpty ? '…' : link.label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              onPressed: () => onOpen(link),
            ),
        ],
      ),
    );
  }
}
