import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:knit/features/audio_playback/presentation/audio_playback_controller.dart';
import 'package:knit/features/collection_present/domain/present_models.dart';
import 'package:knit/features/collection_present/presentation/widgets/slide_notes.dart';
import 'package:knit/features/collection_present/presentation/widgets/slide_photos.dart';
import 'package:knit/features/collection_present/presentation/widgets/slide_scroll.dart';

/// A card slide (§4.9): its photos pinned — on top in portrait, on the left in
/// landscape — and its notes beside them on their own panel, scrolling when
/// long. A slide without photos gives its notes the whole page, in larger type.
class CardSlideView extends StatelessWidget {
  const CardSlideView({
    super.key,
    required this.photos,
    required this.notes,
    required this.photoLinks,
    required this.playback,
    required this.onOpenPhoto,
    required this.onOpenUrl,
    required this.onToggleAudio,
    required this.onOpenLink,
    required this.onNext,
    required this.onPrevious,
  });

  final List<SlidePhoto> photos;
  final List<PresentCard> notes;
  final List<PresentLink> photoLinks;
  final ValueListenable<PlaybackSnapshot> playback;
  final ValueChanged<int> onOpenPhoto;
  final ValueChanged<String> onOpenUrl;
  final ValueChanged<PresentCard> onToggleAudio;
  final ValueChanged<PresentLink> onOpenLink;
  final VoidCallback onNext;
  final VoidCallback onPrevious;

  /// The share of a portrait slide the photos take.
  static const double _photoShare = 0.55;

  @override
  Widget build(BuildContext context) {
    final hasNotes = notes.isNotEmpty || photoLinks.isNotEmpty;
    if (photos.isEmpty) return _notes(large: true);
    final pinned = SlidePhotos(photos: photos, onOpen: onOpenPhoto);
    if (!hasNotes) return pinned;
    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth > constraints.maxHeight) {
          return Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(flex: 3, child: pinned),
              Expanded(flex: 2, child: _notes(large: false)),
            ],
          );
        }
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SizedBox(
              height: constraints.maxHeight * _photoShare,
              child: pinned,
            ),
            Expanded(child: _notes(large: false)),
          ],
        );
      },
    );
  }

  Widget _notes({required bool large}) {
    final notes = SlideNotes(
      notes: this.notes,
      photoLinks: photoLinks,
      playback: playback,
      onOpenUrl: onOpenUrl,
      onToggleAudio: onToggleAudio,
      onOpenLink: onOpenLink,
      large: large,
    );
    final scroll = SlideScroll(
      onNext: onNext,
      onPrevious: onPrevious,
      padding: EdgeInsets.fromLTRB(24, large ? 48 : 20, 24, 32),
      child: notes,
    );
    // A text-only slide centres short notes; long ones scroll from the top.
    if (!large) return scroll;
    return LayoutBuilder(
      builder: (context, constraints) => Align(
        alignment: Alignment.center,
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxWidth: 720,
            maxHeight: constraints.maxHeight,
          ),
          child: scroll,
        ),
      ),
    );
  }
}
