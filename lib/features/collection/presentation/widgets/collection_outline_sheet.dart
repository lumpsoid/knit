import 'package:flutter/material.dart';
import 'package:knit/features/collection/domain/collection_models.dart';
import 'package:knit/features/collection/domain/collection_outline.dart';
import 'package:knit/features/collection/presentation/collection_state.dart';
import 'package:knit/l10n/app_localizations.dart';

/// The Outline (bottom sheet, §4.2): the collection's emphasized cards in feed
/// order, one line each, or a hint while there are none. Pops the tapped
/// entry's card id.
class CollectionOutlineSheet extends StatelessWidget {
  const CollectionOutlineSheet({
    super.key,
    required this.status,
    required this.entries,
  });

  final OutlineStatus status;
  final List<OutlineEntry> entries;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final Widget body = switch (status) {
      OutlineStatus.idle || OutlineStatus.loading => const Padding(
        padding: EdgeInsets.all(32),
        child: Center(child: CircularProgressIndicator()),
      ),
      OutlineStatus.failed => Padding(
        padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
        child: Text(l10n.collectionOutlineError),
      ),
      OutlineStatus.ready when entries.isEmpty => Padding(
        padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
        child: Text(
          l10n.collectionOutlineEmpty,
          style: theme.textTheme.bodyMedium?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
      ),
      OutlineStatus.ready => Flexible(
        child: ListView.builder(
          shrinkWrap: true,
          itemCount: entries.length,
          itemBuilder: (context, i) {
            final entry = entries[i];
            return ListTile(
              leading: Icon(_iconOf(entry.kind)),
              title: Text(
                entry.label ?? _kindName(l10n, entry.kind),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              onTap: () => Navigator.of(context).pop(entry.cardId),
            );
          },
        ),
      ),
    };
    return SafeArea(
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.sizeOf(context).height * 0.7,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 20, 24, 8),
              child: Text(
                l10n.collectionOutlineTitle,
                style: theme.textTheme.titleMedium,
              ),
            ),
            body,
          ],
        ),
      ),
    );
  }

  static IconData _iconOf(CardKind kind) => switch (kind) {
    CardKind.image => Icons.image_outlined,
    CardKind.audio => Icons.mic_none,
    CardKind.file => Icons.insert_drive_file_outlined,
    CardKind.link => Icons.link,
    CardKind.text || CardKind.unknown => Icons.short_text,
  };

  /// What a row without a label shows: its card's kind.
  static String _kindName(AppLocalizations l10n, CardKind kind) =>
      switch (kind) {
        CardKind.image => l10n.collectionCardPhoto,
        CardKind.audio => l10n.collectionCardAudio,
        CardKind.file => l10n.collectionCardFile,
        CardKind.link => l10n.collectionCardLink,
        CardKind.text || CardKind.unknown => l10n.labelEmptyNote,
      };
}
