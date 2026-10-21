import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:knit/core/attachments/presentation/attachment_image.dart';

/// The shared [Hero] tag tying one of a card's feed images to its full-screen
/// preview, so the open/close transition flies between the two. [index] is
/// the image's place on the card (§4.2).
Object imageHeroTag(String cardId, [int index = 0]) =>
    index == 0 ? 'card-image-$cardId' : 'card-image-$cardId-$index';

/// An image card's several images in its bubble (§4.2), in a [size] square:
/// two side by side, three as one tall and two small, four or more as a 2×2
/// grid whose last tile says how many more there are. Takes primitives only
/// (widgets.md §1): each image's decoded bytes, null while loading.
class CardImageGrid extends StatelessWidget {
  const CardImageGrid({
    super.key,
    required this.cardId,
    required this.images,
    this.onImageTap,
    this.size = 220,
  }) : assert(images.length > 1);

  final String cardId;
  final List<Uint8List?> images;

  /// Opens the full-screen preview on the tapped image; null leaves the tap to
  /// the bubble. A tile still loading never opens it.
  final ValueChanged<int>? onImageTap;
  final double size;

  static const double _gap = 2;

  /// The most tiles the grid shows; the last one carries "+N".
  static const int _maxTiles = 4;

  @override
  Widget build(BuildContext context) {
    final half = (size - _gap) / 2;
    final count = images.length;
    final grid = switch (count) {
      2 => Row(
        children: [
          _tile(0, half, size),
          const SizedBox(width: _gap),
          _tile(1, half, size),
        ],
      ),
      3 => Row(
        children: [
          _tile(0, half, size),
          const SizedBox(width: _gap),
          Column(
            children: [
              _tile(1, half, half),
              const SizedBox(height: _gap),
              _tile(2, half, half),
            ],
          ),
        ],
      ),
      _ => Column(
        children: [
          Row(
            children: [
              _tile(0, half, half),
              const SizedBox(width: _gap),
              _tile(1, half, half),
            ],
          ),
          const SizedBox(height: _gap),
          Row(
            children: [
              _tile(2, half, half),
              const SizedBox(width: _gap),
              _tile(3, half, half, more: count - _maxTiles),
            ],
          ),
        ],
      ),
    };
    return ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: SizedBox.square(dimension: size, child: grid),
    );
  }

  /// The image at [index] in a [width]×[height] tile; [more] > 0 covers it
  /// with how many images the grid leaves out.
  Widget _tile(int index, double width, double height, {int more = 0}) {
    final bytes = images[index];
    final onImageTap = bytes == null ? null : this.onImageTap;
    Widget tile = AttachmentImage(bytes: bytes, width: width, height: height);
    // Only the photo flies to the preview, never the "+N" cover.
    if (onImageTap != null) {
      tile = Hero(tag: imageHeroTag(cardId, index), child: tile);
    }
    if (more > 0) {
      tile = Stack(
        children: [
          tile,
          Positioned.fill(
            child: ColoredBox(
              color: const Color(0x8A000000),
              child: Center(
                child: Text(
                  '+$more',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 24,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          ),
        ],
      );
    }
    if (onImageTap == null) return tile;
    return GestureDetector(onTap: () => onImageTap(index), child: tile);
  }
}
