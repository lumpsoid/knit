import 'package:flutter/material.dart';
import 'package:knit/l10n/app_localizations.dart';

enum CollectionMenuAction {
  search,
  present,
  outline,
  reorder,
  shareFile,
  delete,
  saveCopy,
  remove,
}

/// The Collection app bar's ⋮ sheet: Search in collection, Present (§4.9),
/// Outline and Reorder (§4.2), Share as file (docs/collection_share.md) and
/// Delete. An imported collection offers Search, Present, Outline, Save a copy,
/// Share as file (re-shared verbatim) and Remove instead.
class CollectionMenuSheet extends StatelessWidget {
  const CollectionMenuSheet({
    super.key,
    required this.canPresent,
    required this.canReorder,
    this.canEdit = true,
  });

  /// Whether the collection is this identity's own; an imported one
  /// (docs/collection_share.md) swaps Reorder and Delete for Save a copy and
  /// Remove.
  final bool canEdit;

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
            leading: const Icon(Icons.search),
            title: Text(l10n.collectionMenuSearch),
            onTap: () => Navigator.of(context).pop(CollectionMenuAction.search),
          ),
          ListTile(
            leading: const Icon(Icons.slideshow_outlined),
            title: Text(l10n.collectionMenuPresent),
            enabled: canPresent,
            onTap: () =>
                Navigator.of(context).pop(CollectionMenuAction.present),
          ),
          ListTile(
            leading: const Icon(Icons.toc),
            title: Text(l10n.collectionMenuOutline),
            onTap: () =>
                Navigator.of(context).pop(CollectionMenuAction.outline),
          ),
          if (canReorder)
            ListTile(
              leading: const Icon(Icons.swap_vert),
              title: Text(l10n.collectionMenuReorder),
              onTap: () =>
                  Navigator.of(context).pop(CollectionMenuAction.reorder),
            ),
          if (!canEdit)
            ListTile(
              leading: const Icon(Icons.library_add_outlined),
              title: Text(l10n.collectionMenuSaveCopy),
              onTap: () =>
                  Navigator.of(context).pop(CollectionMenuAction.saveCopy),
            ),
          ListTile(
            leading: const Icon(Icons.ios_share),
            title: Text(l10n.collectionMenuShareFile),
            onTap: () =>
                Navigator.of(context).pop(CollectionMenuAction.shareFile),
          ),
          if (canEdit)
            ListTile(
              leading: Icon(
                Icons.delete_outline,
                color: theme.colorScheme.error,
              ),
              title: Text(
                l10n.collectionMenuDelete,
                style: TextStyle(color: theme.colorScheme.error),
              ),
              onTap: () =>
                  Navigator.of(context).pop(CollectionMenuAction.delete),
            ),
          if (!canEdit)
            ListTile(
              leading: Icon(
                Icons.remove_circle_outline,
                color: theme.colorScheme.error,
              ),
              title: Text(
                l10n.collectionMenuRemove,
                style: TextStyle(color: theme.colorScheme.error),
              ),
              onTap: () =>
                  Navigator.of(context).pop(CollectionMenuAction.remove),
            ),
        ],
      ),
    );
  }
}
