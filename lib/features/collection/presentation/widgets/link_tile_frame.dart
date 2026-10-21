import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:knit/core/attachments/presentation/attachment_image.dart';

/// The frame both Connection-card tiles share in the feed (§4.2): a solid,
/// translucent ring around a square image (or [glyph]), the tile's [lines]
/// and a chevron, with the card's own [caption] above when it has one. A tap
/// anywhere on the ring calls [onTap]. Takes primitives only (widgets.md §1).
class LinkTileFrame extends StatelessWidget {
  const LinkTileFrame({
    super.key,
    required this.imageBytes,
    required this.glyph,
    required this.lines,
    required this.semanticLabel,
    required this.onTap,
    this.caption,
  });

  /// Decoded image bytes; null when there is none or they haven't loaded.
  final Uint8List? imageBytes;

  /// The icon standing in for a missing image; it tells the tiles apart.
  final IconData glyph;

  /// The text lines beside the image, top to bottom.
  final List<Widget> lines;

  /// What a tap does, for assistive tech ("Open collection").
  final String semanticLabel;

  /// The card's own text, when it says more than the target's name.
  final String? caption;
  final VoidCallback onTap;

  static const double _imageSize = 48;
  static const double _maxWidth = 260;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final tile = ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: _maxWidth),
      child: DecoratedBox(
        // A solid, translucent ring sets the tile apart inside the bubble.
        decoration: BoxDecoration(
          color: scheme.surface.withValues(alpha: 0.6),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: scheme.outlineVariant.withValues(alpha: 0.7),
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(8),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              _image(scheme),
              const SizedBox(width: 10),
              Flexible(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: lines,
                ),
              ),
              const SizedBox(width: 4),
              Icon(Icons.chevron_right, color: scheme.onSurfaceVariant),
            ],
          ),
        ),
      ),
    );
    final link = Semantics(
      button: true,
      label: semanticLabel,
      child: GestureDetector(onTap: onTap, child: tile),
    );
    final caption = this.caption;
    if (caption == null) return link;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: _maxWidth),
          child: Text(caption),
        ),
        const SizedBox(height: 8),
        link,
      ],
    );
  }

  Widget _image(ColorScheme scheme) {
    final placeholder = SizedBox(
      width: _imageSize,
      height: _imageSize,
      child: ColoredBox(
        color: scheme.primaryContainer,
        child: Icon(glyph, color: scheme.onPrimaryContainer),
      ),
    );
    return ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: imageBytes == null
          ? placeholder
          : AttachmentImage(
              bytes: imageBytes,
              width: _imageSize,
              height: _imageSize,
              placeholder: placeholder,
            ),
    );
  }
}
