import 'package:flutter/material.dart';
import 'package:knit/features/collection_present/domain/present_models.dart';
import 'package:knit/features/collection_present/presentation/widgets/see_also_chips.dart';
import 'package:knit/features/collection_present/presentation/widgets/slide_photos.dart';
import 'package:knit/features/collection_present/presentation/widgets/slide_scroll.dart';
import 'package:knit/l10n/app_localizations.dart';

/// A Connection card's slide (§4.9): the target's picture (a collection's
/// cover, a card's first image) pinned like a title slide's cover, its name,
/// the card's label as a caption, and an Open that follows the link — a
/// collection, or the card's collection at its slide, presented on top.
class LinkSlideView extends StatelessWidget {
  const LinkSlideView({
    super.key,
    required this.target,
    required this.caption,
    required this.picture,
    required this.seeAlso,
    required this.onOpen,
    required this.onOpenLink,
    required this.onNext,
    required this.onPrevious,
  });

  final PresentLink target;

  /// The card's own label, when it says more than the target's name.
  final String? caption;

  /// The target's picture; null when it has none.
  final SlidePhoto? picture;

  /// The card's other links (backlinks).
  final List<PresentLink> seeAlso;
  final VoidCallback onOpen;
  final ValueChanged<PresentLink> onOpenLink;
  final VoidCallback onNext;
  final VoidCallback onPrevious;

  @override
  Widget build(BuildContext context) {
    final picture = this.picture;
    final text = _text(context);
    if (picture == null) return Center(child: text);
    final photos = SlidePhotos(photos: [picture], onOpen: (_) => onOpen());
    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth > constraints.maxHeight) {
          return Row(
            children: [
              Expanded(flex: 3, child: photos),
              Expanded(flex: 2, child: Center(child: text)),
            ],
          );
        }
        return Column(
          children: [
            SizedBox(height: constraints.maxHeight * 0.5, child: photos),
            Expanded(child: Center(child: text)),
          ],
        );
      },
    );
  }

  Widget _text(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);
    final muted = theme.colorScheme.onSurfaceVariant;
    final isCollection = target.kind == PresentLinkKind.collection;
    final name = target.label.isEmpty ? l10n.labelUntitled : target.label;
    final home = target.collectionTitle?.trim() ?? '';
    final caption = this.caption;
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 720),
      child: SlideScroll(
        onNext: onNext,
        onPrevious: onPrevious,
        padding: const EdgeInsets.fromLTRB(24, 32, 24, 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (caption != null) ...[
              Text(
                caption,
                textAlign: TextAlign.center,
                style: theme.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w400,
                  height: 1.45,
                ),
              ),
              const SizedBox(height: 16),
            ],
            Icon(
              isCollection ? Icons.folder_outlined : Icons.notes,
              color: muted,
            ),
            const SizedBox(height: 8),
            Text(
              name,
              textAlign: TextAlign.center,
              maxLines: 4,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.headlineMedium?.copyWith(
                fontWeight: FontWeight.w600,
                height: 1.2,
              ),
            ),
            if (!isCollection) ...[
              const SizedBox(height: 8),
              Text(
                l10n.collectionCardLinkTileIn(
                  home.isEmpty ? l10n.labelUntitled : home,
                ),
                textAlign: TextAlign.center,
                style: theme.textTheme.titleMedium?.copyWith(color: muted),
              ),
            ],
            const SizedBox(height: 24),
            Center(
              child: FilledButton.icon(
                onPressed: onOpen,
                icon: const Icon(Icons.arrow_forward),
                label: Text(
                  isCollection
                      ? l10n.collectionLinkTileOpen
                      : l10n.collectionCardLinkTileOpen,
                ),
              ),
            ),
            if (seeAlso.isNotEmpty) ...[
              const SizedBox(height: 16),
              SeeAlsoChips(links: seeAlso, onOpen: onOpenLink),
            ],
          ],
        ),
      ),
    );
  }
}
