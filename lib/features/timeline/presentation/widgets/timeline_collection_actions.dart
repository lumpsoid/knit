import 'package:flutter/material.dart';
import 'package:knit/features/timeline/presentation/timeline_action.dart';
import 'package:knit/l10n/app_localizations.dart';

/// What the long-press actions sheet of a collection row resolved to.
enum TimelineCollectionAction {
  pin,
  unpin,
  archive,
  unarchive,
  delete;

  /// The Timeline intent this choice dispatches for [collectionId].
  TimelineAction toAction(String collectionId) => switch (this) {
    pin => PinToggled(collectionId, pinned: true),
    unpin => PinToggled(collectionId, pinned: false),
    archive => ArchiveToggled(collectionId, archived: true),
    unarchive => ArchiveToggled(collectionId, archived: false),
    delete => DeleteCollectionRequested(collectionId),
  };
}

/// Long-press a collection row → actions sheet (§4.1): Pin / Unpin (Home
/// only), Archive / Unarchive (§3.4), and Delete — guarded by a confirmation
/// dialog since it's destructive. Resolves to the chosen action, or null when
/// the sheet or the confirmation was dismissed.
Future<TimelineCollectionAction?> showTimelineCollectionActions(
  BuildContext context, {
  required String title,
  required bool isPinned,
  required bool isArchived,
}) async {
  final action = await showModalBottomSheet<TimelineCollectionAction>(
    context: context,
    builder: (_) =>
        _CollectionActionsSheet(isPinned: isPinned, isArchived: isArchived),
  );
  if (action != TimelineCollectionAction.delete || !context.mounted) {
    return action;
  }
  final confirmed = await _confirmDelete(context, title);
  return confirmed ? action : null;
}

Future<bool> _confirmDelete(BuildContext context, String name) async {
  final l10n = AppLocalizations.of(context);
  final title = name.trim().isEmpty ? l10n.labelUntitled : name;
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: Text(l10n.timelineDeleteTitle),
      content: Text(l10n.timelineDeleteBody(title)),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(dialogContext).pop(false),
          child: Text(l10n.actionCancel),
        ),
        FilledButton(
          onPressed: () => Navigator.of(dialogContext).pop(true),
          child: Text(l10n.actionDelete),
        ),
      ],
    ),
  );
  return confirmed == true;
}

class _CollectionActionsSheet extends StatelessWidget {
  const _CollectionActionsSheet({
    required this.isPinned,
    required this.isArchived,
  });

  /// Whether the row is pinned — offers Unpin instead of Pin.
  final bool isPinned;

  /// Whether the row is archived — offers Unarchive instead of Archive, and no
  /// pinning (an archived collection is never on Home).
  final bool isArchived;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);
    return SafeArea(
      child: Wrap(
        children: [
          if (!isArchived)
            ListTile(
              leading: Icon(
                isPinned ? Icons.push_pin : Icons.push_pin_outlined,
              ),
              title: Text(isPinned ? l10n.actionUnpin : l10n.actionPin),
              onTap: () => Navigator.of(context).pop(
                isPinned
                    ? TimelineCollectionAction.unpin
                    : TimelineCollectionAction.pin,
              ),
            ),
          ListTile(
            leading: Icon(
              isArchived ? Icons.unarchive_outlined : Icons.archive_outlined,
            ),
            title: Text(isArchived ? l10n.actionUnarchive : l10n.actionArchive),
            onTap: () => Navigator.of(context).pop(
              isArchived
                  ? TimelineCollectionAction.unarchive
                  : TimelineCollectionAction.archive,
            ),
          ),
          ListTile(
            leading: Icon(Icons.delete_outline, color: theme.colorScheme.error),
            title: Text(
              l10n.actionDelete,
              style: TextStyle(color: theme.colorScheme.error),
            ),
            onTap: () =>
                Navigator.of(context).pop(TimelineCollectionAction.delete),
          ),
        ],
      ),
    );
  }
}
