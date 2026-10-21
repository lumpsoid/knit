import 'package:flutter/material.dart';
import 'package:knit/features/collection_present/presentation/widgets/slide_photos.dart';
import 'package:knit/features/collection_present/presentation/widgets/slide_scroll.dart';
import 'package:knit/l10n/app_localizations.dart';

/// Slide 0 (§4.9): the collection's cover, title and description, the offer
/// to continue where the last presentation was left, and a hint to swipe up.
class TitleSlideView extends StatelessWidget {
  const TitleSlideView({
    super.key,
    required this.title,
    required this.description,
    required this.cover,
    required this.resumeSlideNumber,
    required this.hasSlides,
    required this.onResume,
    required this.onOpenCover,
    required this.onNext,
    required this.onPrevious,
  });

  final String title;
  final String? description;

  /// The cover photo; null when the collection has none.
  final SlidePhoto? cover;

  /// The 1-based slide to continue from; null hides the offer.
  final int? resumeSlideNumber;

  /// Whether any card slide follows; otherwise the hint says there's nothing.
  final bool hasSlides;
  final VoidCallback onResume;
  final VoidCallback onOpenCover;
  final VoidCallback onNext;
  final VoidCallback onPrevious;

  @override
  Widget build(BuildContext context) {
    final cover = this.cover;
    final text = _text(context);
    return LayoutBuilder(
      builder: (context, constraints) {
        if (cover == null) return Center(child: text);
        final photos = SlidePhotos(
          photos: [cover],
          onOpen: (_) => onOpenCover(),
        );
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
    final description = this.description?.trim();
    final resume = resumeSlideNumber;
    return SlideScroll(
      onNext: onNext,
      onPrevious: onPrevious,
      padding: const EdgeInsets.fromLTRB(24, 32, 24, 32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            title,
            textAlign: TextAlign.center,
            style: theme.textTheme.displaySmall?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
          if (description != null && description.isNotEmpty) ...[
            const SizedBox(height: 16),
            Text(
              description,
              textAlign: TextAlign.center,
              style: theme.textTheme.titleMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
                height: 1.4,
              ),
            ),
          ],
          const SizedBox(height: 32),
          if (resume != null) ...[
            Center(
              child: FilledButton.tonalIcon(
                onPressed: onResume,
                icon: const Icon(Icons.play_arrow),
                label: Text(l10n.presentContinueFrom(resume)),
              ),
            ),
            const SizedBox(height: 16),
          ],
          Column(
            children: [
              if (hasSlides)
                Icon(
                  Icons.keyboard_arrow_up,
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              Text(
                hasSlides ? l10n.presentSwipeHint : l10n.presentEmpty,
                style: theme.textTheme.labelLarge?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
