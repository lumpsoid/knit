import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:knit/core/attachments/presentation/attachment_image.dart';
import 'package:knit/features/collection/presentation/widgets/title_morph.dart';
import 'package:knit/l10n/app_localizations.dart';

/// The Collection app bar: the title card, docked. As the card scrolls under
/// it, the bar takes the card's surface, the name flies in from the card
/// ([TitleMorphFlight] draws it into the [TitleMorphTarget] slot here), and the
/// cover thumbnail and the Connections button arrive with it, so the card's
/// header stays at hand however far down the feed is. Takes primitives only
/// (widgets.md §1).
class CollectionHeaderBar extends StatelessWidget
    implements PreferredSizeWidget {
  const CollectionHeaderBar({
    super.key,
    required this.titleMorph,
    required this.title,
    required this.hasCover,
    required this.coverBytes,
    required this.connectionCount,
    required this.onTitleTap,
    required this.onConnectionsTap,
    this.actions = const [],
  });

  /// The name's style in the bar; the flight lands on it.
  static TextStyle titleStyle(ThemeData theme) =>
      theme.appBarTheme.titleTextStyle ??
      theme.textTheme.titleLarge ??
      const TextStyle(fontSize: 22);

  final TitleMorphLink titleMorph;

  /// The collection's name, already resolved for display.
  final String title;

  /// Whether a cover is set — a thumbnail leads the name (a placeholder shows
  /// while its bytes load).
  final bool hasCover;
  final Uint8List? coverBytes;

  /// How many links the collection itself takes part in (§4.4).
  final int connectionCount;

  /// Tapping the docked name does what tapping the card does.
  final VoidCallback? onTitleTap;

  /// Open the collection's Connections view (§4.4).
  final VoidCallback onConnectionsTap;

  /// The screen's own actions, after the Connections button.
  final List<Widget> actions;

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);
    final scheme = theme.colorScheme;
    return AppBar(
      // The bar's surface follows the flight rather than any scroll under it.
      notificationPredicate: (_) => false,
      scrolledUnderElevation: 0,
      backgroundColor: scheme.surface,
      flexibleSpace: TitleMorphReveal(
        link: titleMorph,
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: theme.cardTheme.color ?? scheme.surfaceContainerLow,
            border: Border(bottom: BorderSide(color: scheme.outlineVariant)),
          ),
        ),
      ),
      // Only a docked name takes taps; until then the slot is empty.
      title: TitleMorphReveal(
        link: titleMorph,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: onTitleTap,
          child: Row(
            children: [
              if (hasCover)
                TitleMorphReveal(
                  link: titleMorph,
                  fromScale: 0.6,
                  child: Padding(
                    padding: const EdgeInsetsDirectional.only(end: 12),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: AttachmentImage(
                        bytes: coverBytes,
                        width: 32,
                        height: 32,
                      ),
                    ),
                  ),
                ),
              Expanded(
                child: TitleMorphTarget(
                  link: titleMorph,
                  child: Text(
                    title,
                    style: titleStyle(theme),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TitleMorphReveal(
          link: titleMorph,
          fromScale: 0.6,
          child: IconButton(
            tooltip: l10n.collectionConnectionsTooltip,
            onPressed: onConnectionsTap,
            icon: Badge(
              isLabelVisible: connectionCount > 0,
              label: Text('$connectionCount'),
              backgroundColor: scheme.primary,
              child: const Icon(Icons.hub_outlined),
            ),
          ),
        ),
        ...actions,
      ],
    );
  }
}
