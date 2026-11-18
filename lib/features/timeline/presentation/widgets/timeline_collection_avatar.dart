import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:knit/core/attachments/presentation/attachment_image.dart';

/// A collection's leading glyph in Home: its cover image (clipped to the avatar
/// circle) when its bytes are loaded, otherwise the lettered-avatar placeholder
/// tinted from the collection id.
class TimelineCollectionAvatar extends StatelessWidget {
  const TimelineCollectionAvatar({
    super.key,
    required this.collectionId,
    required this.title,
    required this.coverBytes,
  });

  /// The collection id, which seeds the placeholder's tint.
  final String collectionId;

  /// The display title (non-empty); its first letter is the placeholder's.
  final String title;

  /// Decoded cover bytes, or null when the collection has no cover or its bytes
  /// haven't loaded.
  final Uint8List? coverBytes;

  @override
  Widget build(BuildContext context) {
    final bytes = coverBytes;
    if (bytes != null) {
      return ClipOval(
        child: AttachmentImage(
          bytes: bytes,
          width: 40,
          height: 40,
          placeholder: _letterAvatar(),
        ),
      );
    }
    return _letterAvatar();
  }

  Widget _letterAvatar() => CircleAvatar(
    backgroundColor: _tint(collectionId),
    child: Text(
      title.substring(0, 1).toUpperCase(),
      style: const TextStyle(color: Colors.white),
    ),
  );

  Color _tint(String seed) {
    final h = seed.codeUnits.fold<int>(0, (a, c) => (a * 31 + c) & 0xFFFF);
    return HSLColor.fromAHSL(1, (h % 360).toDouble(), 0.5, 0.5).toColor();
  }
}
