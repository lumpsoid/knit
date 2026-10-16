import 'package:flutter/material.dart';
import 'package:knit/l10n/app_localizations.dart';

enum CardAction { edit, delete, link, copy, share }

class CardActionsSheet extends StatelessWidget {
  const CardActionsSheet({super.key, required this.canCopy});

  /// Whether the card has text to copy; hides the Copy entry otherwise.
  final bool canCopy;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);
    return SafeArea(
      child: Wrap(
        children: [
          ListTile(
            leading: const Icon(Icons.edit_outlined),
            title: Text(l10n.collectionActionEdit),
            onTap: () => Navigator.of(context).pop(CardAction.edit),
          ),
          ListTile(
            leading: const Icon(Icons.link),
            title: Text(l10n.collectionActionMakeLink),
            onTap: () => Navigator.of(context).pop(CardAction.link),
          ),
          if (canCopy)
            ListTile(
              leading: const Icon(Icons.copy),
              title: Text(l10n.collectionActionCopy),
              onTap: () => Navigator.of(context).pop(CardAction.copy),
            ),
          ListTile(
            leading: const Icon(Icons.ios_share),
            title: Text(l10n.collectionActionShare),
            onTap: () => Navigator.of(context).pop(CardAction.share),
          ),
          ListTile(
            leading: Icon(Icons.delete_outline, color: theme.colorScheme.error),
            title: Text(
              l10n.collectionActionDelete,
              style: TextStyle(color: theme.colorScheme.error),
            ),
            onTap: () => Navigator.of(context).pop(CardAction.delete),
          ),
        ],
      ),
    );
  }
}
