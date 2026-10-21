import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:knit/core/attachments/presentation/attachment_image.dart';

/// The shared [Hero] tag tying a slide photo to its full-screen view.
Object presentImageHeroTag(String id) => 'present-image-$id';

/// One photo on a slide — a widget-owned view-model (widgets.md §1).
@immutable
class SlidePhoto {
  const SlidePhoto({required this.id, required this.bytes, this.caption});

  /// The card (or cover) the photo belongs to; keys its [Hero].
  final String id;

  /// Decoded bytes; null while loading or missing.
  final Uint8List? bytes;
  final String? caption;
}

/// A slide's pinned photos (§4.9): one photo, or a carousel swiped sideways
/// with dots when there are several. The caption sits under the photo, never
/// over it. Tapping a loaded photo opens it full screen.
class SlidePhotos extends StatefulWidget {
  const SlidePhotos({super.key, required this.photos, required this.onOpen})
    : assert(photos.length > 0);

  final List<SlidePhoto> photos;

  /// Open photo [index] full screen.
  final ValueChanged<int> onOpen;

  /// The backdrop behind photos, the same in light and dark themes.
  static const Color backdrop = Color(0xFF121212);

  @override
  State<SlidePhotos> createState() => _SlidePhotosState();
}

class _SlidePhotosState extends State<SlidePhotos> {
  int _index = 0;

  @override
  Widget build(BuildContext context) {
    final photos = widget.photos;
    final caption = photos[_index.clamp(0, photos.length - 1)].caption?.trim();
    return ColoredBox(
      color: SlidePhotos.backdrop,
      child: Column(
        children: [
          Expanded(
            child: PageView.builder(
              itemCount: photos.length,
              onPageChanged: (i) => setState(() => _index = i),
              itemBuilder: (context, i) => _photo(photos[i], i),
            ),
          ),
          if (photos.length > 1) _dots(photos.length),
          if (caption != null && caption.isNotEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
              child: Text(
                caption,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.white70),
              ),
            ),
        ],
      ),
    );
  }

  Widget _photo(SlidePhoto photo, int index) {
    final bytes = photo.bytes;
    return GestureDetector(
      onTap: bytes == null ? null : () => widget.onOpen(index),
      child: Hero(
        tag: presentImageHeroTag(photo.id),
        child: AttachmentImage(
          bytes: bytes,
          fit: BoxFit.contain,
          width: double.infinity,
          height: double.infinity,
          placeholder: const Center(
            child: Icon(Icons.image_outlined, color: Colors.white38, size: 48),
          ),
        ),
      ),
    );
  }

  Widget _dots(int count) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 8),
    child: Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        for (var i = 0; i < count; i++)
          AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            margin: const EdgeInsets.symmetric(horizontal: 3),
            width: i == _index ? 8 : 6,
            height: i == _index ? 8 : 6,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: i == _index ? Colors.white : Colors.white38,
            ),
          ),
      ],
    ),
  );
}
