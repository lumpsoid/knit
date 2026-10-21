import 'package:flutter/material.dart';
import 'package:knit/l10n/app_localizations.dart';

enum CollectionMenuAction { present, reorder, shareFile, delete }

/// The Collection app bar's ⋮ sheet: Present (§4.9), Reorder (§4.2), Share
/// as file (docs/collection_share.md) and Delete.
class CollectionMenuSheet extends StatelessWidget {
  const CollectionMenuSheet({
    super.key,
    required this.canPresent,
    required this.canReorder,
  });

  /// Whether there are cards to present; the entry is disabled otherwise.
  final bool canPresent;

  /// Whether the feed can be reordered; hides the entry otherwise.
  final bool canReorder;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);
    return SafeArea(
      child: Wrap(
        children: [
          ListTile(
            leading: const Icon(Icons.slideshow_outlined),
            title: Text(l10n.collectionMenuPresent),
            enabled: canPresent,
            onTap: () =>
                Navigator.of(context).pop(CollectionMenuAction.present),
          ),
          if (canReorder)
            ListTile(
              leading: const Icon(Icons.swap_vert),
              title: Text(l10n.collectionMenuReorder),
              onTap: () =>
                  Navigator.of(context).pop(CollectionMenuAction.reorder),
            ),
          ListTile(
            leading: const Icon(Icons.ios_share),
            title: Text(l10n.collectionMenuShareFile),
            onTap: () =>
                Navigator.of(context).pop(CollectionMenuAction.shareFile),
          ),
          ListTile(
            leading: Icon(Icons.delete_outline, color: theme.colorScheme.error),
            title: Text(
              l10n.collectionMenuDelete,
              style: TextStyle(color: theme.colorScheme.error),
            ),
            onTap: () => Navigator.of(context).pop(CollectionMenuAction.delete),
          ),
        ],
      ),
    );
  }
}
