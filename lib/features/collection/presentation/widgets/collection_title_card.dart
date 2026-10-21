import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:knit/core/attachments/presentation/attachment_image.dart';
import 'package:knit/features/collection/presentation/widgets/title_morph.dart';
import 'package:knit/l10n/app_localizations.dart';

/// The shared [Hero] tag tying a collection's cover banner to its full-screen
/// preview.
Object coverHeroTag(String collectionId) => 'collection-cover-$collectionId';

/// The collection's header, rendered as a distinct top-most card in the feed
/// (§4.2) — visually set apart from the chat bubbles (a full-width elevated card
/// with an optional cover banner). Shows the cover (if set), the title, the
/// optional description, and a Connections affordance (with a count badge when
/// the collection itself is linked); tapping the card opens the collection-edit
/// page. Takes primitives only (widgets.md §1).
class CollectionTitleCard extends StatelessWidget {
  const CollectionTitleCard({
    super.key,
    required this.title,
    required this.description,
    required this.hasCover,
    required this.coverBytes,
    required this.coverHeroTag,
    required this.connectionCount,
    required this.onTap,
    required this.onConnectionsTap,
    this.titleMorph,
    this.onCoverTap,
  });

  final String title;
  final String? description;

  /// The name's style in the card; the flight to the app bar starts from it.
  static TextStyle nameStyle(ThemeData theme) =>
      (theme.textTheme.headlineSmall ?? const TextStyle(fontSize: 24)).copyWith(
        fontWeight: FontWeight.w700,
      );

  /// Hands the name to the app bar as the card scrolls away; null keeps it
  /// here.
  final TitleMorphLink? titleMorph;

  /// Whether a cover is set — drives the banner (a placeholder shows while its
  /// bytes load).
  final bool hasCover;
  final Uint8List? coverBytes;

  /// The [Hero] tag the cover shares with its full-screen preview.
  final Object coverHeroTag;

  /// Open the cover full-screen to zoom; null while its bytes are loading, so
  /// a tap on the placeholder falls through to [onTap].
  final VoidCallback? onCoverTap;

  /// How many links the collection itself takes part in (§4.4); a number rides
  /// next to the Connections icon when > 0.
  final int connectionCount;
  final VoidCallback? onTap;

  /// Open the collection's Connections view (§4.4).
  final VoidCallback onConnectionsTap;

  /// The cover banner. Once loaded, tapping it opens the zoom viewer (its own
  /// GestureDetector wins over the card's InkWell, which opens the edit page).
  Widget _cover() {
    final image = AttachmentImage(
      bytes: coverBytes,
      height: 160,
      fit: BoxFit.cover,
    );
    final onCoverTap = this.onCoverTap;
    if (onCoverTap == null) return image;
    return GestureDetector(
      onTap: onCoverTap,
      child: Hero(tag: coverHeroTag, child: image),
    );
  }

  /// The name, filling the text column so a flying copy laid out at its width
  /// wraps the same way.
  Widget _name(String name, ThemeData theme) {
    final text = Text(name, style: nameStyle(theme));
    final link = titleMorph;
    if (link == null) return text;
    return TitleMorphSource(
      link: link,
      child: SizedBox(width: double.infinity, child: text),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);
    final name = title.trim().isEmpty ? l10n.labelUntitled : title.trim();
    final blurb = description?.trim();
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 4, 12, 12),
      child: Card(
        elevation: 2,
        clipBehavior: Clip.antiAlias,
        margin: EdgeInsets.zero,
        child: InkWell(
          onTap: onTap,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: [
              if (hasCover) _cover(),
              Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          _name(name, theme),
                          if (blurb != null && blurb.isNotEmpty) ...[
                            const SizedBox(height: 6),
                            Text(
                              blurb,
                              style: theme.textTheme.bodyMedium?.copyWith(
                                color: theme.colorScheme.onSurfaceVariant,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    // The collection's own Connections affordance (moved here
                    // from the app bar). A count rides next to the icon when the
                    // collection itself is linked; its own InkWell captures the
                    // tap, so it opens Connections rather than the card's edit.
                    Tooltip(
                      message: l10n.collectionConnectionsTooltip,
                      child: InkWell(
                        borderRadius: BorderRadius.circular(20),
                        onTap: onConnectionsTap,
                        child: Padding(
                          padding: const EdgeInsets.all(8),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.hub_outlined,
                                size: 20,
                                color: theme.colorScheme.primary,
                              ),
                              if (connectionCount > 0) ...[
                                const SizedBox(width: 4),
                                Text(
                                  '$connectionCount',
                                  style: theme.textTheme.labelMedium?.copyWith(
                                    color: theme.colorScheme.primary,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                      ),
                    ),
                    Icon(
                      Icons.edit_outlined,
                      size: 20,
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
