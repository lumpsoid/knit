import 'package:flutter/material.dart';
import 'package:knit/l10n/app_localizations.dart';

enum CollectionMenuAction { present, reorder }

/// The Collection app bar's ⋮ sheet: Present (§4.9) and Reorder (§4.2).
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
        ],
      ),
    );
  }
}
