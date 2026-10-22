import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:knit/core/emphasized/emphasized_palette.dart';
import 'package:knit/features/audio_playback/presentation/audio_playback_controller.dart';
import 'package:knit/features/collection/domain/collection_models.dart';
import 'package:knit/features/collection/presentation/widgets/card_bubble.dart';
import 'package:knit/features/collection_present/domain/present_models.dart';
import 'package:knit/features/collection_present/presentation/widgets/see_also_chips.dart';

/// A slide's notes (§4.9): its text, link, audio and file cards in feed order,
/// readable at a distance. An emphasized card reads as a heading with a warm
/// bar. Each card's links follow it as "See also" chips, and the links of the
/// slide's photos close the list.
class SlideNotes extends StatelessWidget {
  const SlideNotes({
    super.key,
    required this.notes,
    required this.photoLinks,
    required this.playback,
    required this.onOpenUrl,
    required this.onToggleAudio,
    required this.onOpenLink,
    this.large = false,
  });

  final List<PresentCard> notes;

  /// The links of the slide's photo cards.
  final List<PresentLink> photoLinks;
  final ValueListenable<PlaybackSnapshot> playback;
  final ValueChanged<String> onOpenUrl;
  final ValueChanged<PresentCard> onToggleAudio;
  final ValueChanged<PresentLink> onOpenLink;

  /// Larger type, for a slide with no photo.
  final bool large;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final card in notes) ...[
          _note(context, card),
          if (card.links.isNotEmpty)
            SeeAlsoChips(links: card.links, onOpen: onOpenLink),
          const SizedBox(height: 16),
        ],
        if (photoLinks.isNotEmpty)
          SeeAlsoChips(links: photoLinks, onOpen: onOpenLink),
      ],
    );
  }

  Widget _note(BuildContext context, PresentCard card) {
    final theme = Theme.of(context);
    final text = card.text?.trim() ?? '';
    final body =
        (large ? theme.textTheme.headlineSmall : theme.textTheme.titleLarge)
            ?.copyWith(fontWeight: FontWeight.w400, height: 1.45);
    final caption = text.isEmpty ? null : Text(text, style: body);
    final content = switch (card.kind) {
      CardKind.link when text.isNotEmpty => _LinkNote(
        url: text,
        onTap: () => onOpenUrl(text),
      ),
      CardKind.audio => _withCaption(
        AudioCardChip(
          cardId: card.id,
          name: card.fileName,
          playback: card.attachmentId == null ? null : playback,
          onToggle: card.attachmentId == null
              ? null
              : () => onToggleAudio(card),
        ),
        caption,
      ),
      CardKind.file => _withCaption(
        FileCardChip(name: card.fileName, size: null, onTap: null),
        caption,
      ),
      _ when card.emphasized && text.isNotEmpty => Text(
        text,
        style:
            (large
                    ? theme.textTheme.displaySmall
                    : theme.textTheme.headlineMedium)
                ?.copyWith(fontWeight: FontWeight.w600, height: 1.2),
      ),
      _ => caption ?? const SizedBox.shrink(),
    };
    if (!card.emphasized) return content;
    return DecoratedBox(
      decoration: BoxDecoration(
        border: Border(
          left: BorderSide(
            color: EmphasizedPalette.frame(theme.brightness),
            width: 4,
          ),
        ),
      ),
      child: Padding(padding: const EdgeInsets.only(left: 14), child: content),
    );
  }

  static Widget _withCaption(Widget chip, Widget? caption) => caption == null
      ? Align(alignment: Alignment.centerLeft, child: chip)
      : Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [chip, const SizedBox(height: 8), caption],
        );
}

/// A link card on a slide: its URL, tappable to open in the browser.
class _LinkNote extends StatelessWidget {
  const _LinkNote({required this.url, required this.onTap});

  final String url;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = theme.colorScheme.primary;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Row(
          children: [
            Icon(Icons.link, color: color),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                url,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.titleMedium?.copyWith(
                  color: color,
                  decoration: TextDecoration.underline,
                  decorationColor: color,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
