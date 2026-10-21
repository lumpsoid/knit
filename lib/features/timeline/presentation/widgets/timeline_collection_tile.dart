import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:knit/core/attachments/presentation/attachment_image.dart';
import 'package:knit/core/settled/settled_palette.dart';
import 'package:knit/features/timeline/presentation/timeline_scope.dart';
import 'package:knit/l10n/app_localizations.dart';
import 'package:knit/sync/sync.dart';

/// One collection row (§4.1): cover or lettered avatar, title, last-card
/// preview · count, and the relative last-updated time. Used by Home and the
/// Archive page.
class TimelineCollectionTile extends StatelessWidget {
  const TimelineCollectionTile({
    super.key,
    required this.summary,
    required this.title,
    required this.coverBytes,
    required this.onTap,
    required this.onLongPress,
    this.fromHandle,
  });

  /// A row for [summary] whose header comes from the shared collection details
  /// (kept fresh by every read and edit), with the summary as the fallback
  /// before it lands, and whose cover comes from the shared image cache.
  factory TimelineCollectionTile.fromScope({
    Key? key,
    required CollectionSummary summary,
    required VoidCallback onTap,
    required VoidCallback onLongPress,
    String? fromHandle,
  }) {
    final header = TimelineScope.collectionDetails.of(summary.collectionId);
    final coverId = header == null
        ? summary.coverAttachmentId
        : header.coverAttachmentId;
    return TimelineCollectionTile(
      key: key,
      summary: summary,
      title: header?.title ?? summary.title,
      coverBytes: coverId == null ? null : TimelineScope.images.of(coverId),
      onTap: onTap,
      onLongPress: onLongPress,
      fromHandle: fromHandle,
    );
  }

  final CollectionSummary summary;

  /// The collection's current title (blank ⇒ shown as untitled).
  final String title;

  /// Decoded cover bytes, or null when the collection has no cover or its bytes
  /// haven't loaded — in which case the lettered-avatar placeholder is shown.
  final Uint8List? coverBytes;
  final VoidCallback onTap;
  final VoidCallback onLongPress;

  /// The creator's `nickname#fingerprint` of an imported, read-only
  /// collection (docs/collection_share.md), shown as a "from" line.
  final String? fromHandle;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);
    final title = this.title.trim().isEmpty ? l10n.labelUntitled : this.title;
    final preview = Text.rich(
      TextSpan(
        children: [
          // A settled newest card (§3.3) previews muted, like its bubble.
          TextSpan(
            text: _preview(l10n, summary.lastCard),
            style: summary.lastCard?.settled == true
                ? TextStyle(
                    color: SettledPalette.previewText(theme.colorScheme),
                  )
                : null,
          ),
          TextSpan(text: ' · ${l10n.timelineCardCount(summary.cardCount)}'),
        ],
      ),
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
    );
    return ListTile(
      onTap: onTap,
      onLongPress: onLongPress,
      leading: _leading(title),
      title: Text(title, maxLines: 1, overflow: TextOverflow.ellipsis),
      subtitle: fromHandle == null
          ? preview
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                preview,
                Text(
                  l10n.timelineFromHandle(fromHandle!),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
      trailing: Text(
        _relative(l10n, summary.lastUpdated),
        style: theme.textTheme.labelSmall?.copyWith(
          color: theme.colorScheme.onSurfaceVariant,
        ),
      ),
    );
  }

  /// A collection row's leading glyph: its cover image (clipped to the avatar
  /// circle) when its bytes are loaded, otherwise the lettered-avatar
  /// placeholder tinted from the collection id.
  Widget _leading(String title) {
    final bytes = coverBytes;
    if (bytes != null) {
      return ClipOval(
        child: AttachmentImage(
          bytes: bytes,
          width: 40,
          height: 40,
          placeholder: _letterAvatar(title),
        ),
      );
    }
    return _letterAvatar(title);
  }

  Widget _letterAvatar(String title) => CircleAvatar(
    backgroundColor: _tint(summary.collectionId),
    child: Text(
      title.substring(0, 1).toUpperCase(),
      style: const TextStyle(color: Colors.white),
    ),
  );

  Color _tint(String seed) {
    final h = seed.codeUnits.fold<int>(0, (a, c) => (a * 31 + c) & 0xFFFF);
    return HSLColor.fromAHSL(1, (h % 360).toDouble(), 0.5, 0.5).toColor();
  }

  String _preview(AppLocalizations l10n, CardPreview? card) {
    if (card == null) return l10n.timelineNoCardsYet;
    switch (card.kind) {
      case 'text':
        final t = card.text?.trim() ?? '';
        return t.isEmpty ? l10n.labelEmptyNote : t;
      case 'image':
        return l10n.timelinePreviewPhoto;
      case 'audio':
        return l10n.timelinePreviewAudio;
      case 'link':
        return l10n.timelinePreviewLink;
      default:
        return card.kind;
    }
  }

  String _relative(AppLocalizations l10n, int ms) {
    final delta = DateTime.now().difference(
      DateTime.fromMillisecondsSinceEpoch(ms),
    );
    if (delta.inMinutes < 1) return l10n.timeNow;
    if (delta.inHours < 1) return l10n.timeMinutesShort(delta.inMinutes);
    if (delta.inDays < 1) return l10n.timeHoursShort(delta.inHours);
    if (delta.inDays < 7) return l10n.timeDaysShort(delta.inDays);
    final d = DateTime.fromMillisecondsSinceEpoch(ms);
    return '${d.day}/${d.month}';
  }
}
