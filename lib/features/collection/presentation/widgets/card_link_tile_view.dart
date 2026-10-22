import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:knit/core/settled/settled_palette.dart';
import 'package:knit/features/collection/presentation/widgets/link_tile_frame.dart';
import 'package:knit/l10n/app_localizations.dart';

/// A card-link card's tile in the feed (§4.2): the linked card's first image
/// (or a note glyph), a two-line preview of it and a small line naming its
/// collection, with the card's own [caption] above when it has one. Muted when
/// the linked card is settled. A tap reveals that card. Takes primitives only
/// (widgets.md §1).
class CardLinkTileView extends StatelessWidget {
  const CardLinkTileView({
    super.key,
    required this.preview,
    required this.collectionTitle,
    required this.thumbnailBytes,
    required this.onTap,
    this.settled = false,
    this.caption,
    this.archived = false,
  });

  /// The linked card's text, file name or kind label, already labelled.
  final String preview;

  /// Its collection's title (blank ⇒ shown as untitled).
  final String collectionTitle;

  /// Whether the linked card is settled (§3.3): the preview is then muted.
  final bool settled;

  /// Decoded bytes of its first image; null when it has none or they haven't
  /// loaded.
  final Uint8List? thumbnailBytes;

  /// The card's own text, when it says more than [preview].
  final String? caption;
  final VoidCallback onTap;

  /// Whether the linked collection (or the linked card's collection) is
  /// archived (§3.4): the tile shows a small "Archived" marker.
  final bool archived;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final l10n = AppLocalizations.of(context);
    final muted = theme.textTheme.bodySmall?.copyWith(
      color: scheme.onSurfaceVariant,
    );
    final title = collectionTitle.trim();
    return LinkTileFrame(
      imageBytes: thumbnailBytes,
      glyph: Icons.sticky_note_2_outlined,
      semanticLabel: l10n.collectionCardLinkTileOpen,
      caption: caption,
      archived: archived,
      onTap: onTap,
      lines: [
        Text(
          preview,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: settled
              ? TextStyle(color: SettledPalette.previewText(scheme))
              : null,
        ),
        Text(
          l10n.collectionCardLinkTileIn(
            title.isEmpty ? l10n.labelUntitled : title,
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: muted,
        ),
      ],
    );
  }
}
