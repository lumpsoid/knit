import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:knit/core/settled/settled_palette.dart';
import 'package:knit/features/collection/presentation/widgets/link_tile_frame.dart';
import 'package:knit/l10n/app_localizations.dart';

/// A collection-link card's tile in the feed (§4.2): the linked collection's
/// cover (or a folder glyph), title, card count and newest card's preview,
/// with the card's own [caption] above when it has one. A tap opens that
/// collection. Takes primitives only (widgets.md §1).
class CollectionLinkTileView extends StatelessWidget {
  const CollectionLinkTileView({
    super.key,
    required this.title,
    required this.cardCount,
    required this.preview,
    required this.coverBytes,
    required this.onTap,
    this.previewSettled = false,
    this.caption,
  });

  /// The linked collection's title (blank ⇒ shown as untitled).
  final String title;
  final int cardCount;

  /// The one-line preview of its newest card, already labelled.
  final String preview;

  /// Whether that newest card is settled (§3.3): its preview is then muted,
  /// like the Home row's.
  final bool previewSettled;

  /// Decoded cover bytes; null when it has no cover or they haven't loaded.
  final Uint8List? coverBytes;

  /// The card's own text, when it says more than [title].
  final String? caption;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final l10n = AppLocalizations.of(context);
    final muted = theme.textTheme.bodySmall?.copyWith(
      color: scheme.onSurfaceVariant,
    );
    return LinkTileFrame(
      imageBytes: coverBytes,
      glyph: Icons.folder_outlined,
      semanticLabel: l10n.collectionLinkTileOpen,
      caption: caption,
      onTap: onTap,
      lines: [
        Text(
          title.trim().isEmpty ? l10n.labelUntitled : title,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
        Text(l10n.timelineCardCount(cardCount), maxLines: 1, style: muted),
        Text(
          preview,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: previewSettled
              ? muted?.copyWith(color: SettledPalette.previewText(scheme))
              : muted,
        ),
      ],
    );
  }
}
