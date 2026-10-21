import 'dart:typed_data';

import 'package:knit/features/collection/domain/collection_failure.dart';
import 'package:result_dart/result_dart.dart';

/// A card's shareable payload — primitives only (widgets.md §1), never a sync
/// domain type. [text] is the card body / caption (null ⇒ no text); [files]
/// are its photos (or its one file), those whose bytes were available.
class ShareableCard {
  const ShareableCard({this.text, this.files = const []});

  final String? text;
  final List<ShareableImage> files;
}

/// A file of a [ShareableCard]: the decoded [bytes], the [mime] the blob store
/// recorded, and the [fileName] the share sheet should present.
class ShareableImage {
  const ShareableImage({
    required this.bytes,
    required this.mime,
    required this.fileName,
  });

  /// Build the share file from [baseName] (e.g. `2026-06-16-knit`), deriving the
  /// extension from [mime] so the saved/shared photo keeps a sensible name.
  factory ShareableImage.named({
    required Uint8List bytes,
    required String mime,
    required String baseName,
  }) => ShareableImage(
    bytes: bytes,
    mime: mime,
    fileName: '$baseName.${_extensionFor(mime)}',
  );

  final Uint8List bytes;
  final String mime;
  final String fileName;

  static String _extensionFor(String mime) => switch (mime) {
    'image/png' => 'png',
    'image/gif' => 'gif',
    'image/webp' => 'webp',
    'image/heic' => 'heic',
    'image/heif' => 'heif',
    _ => 'jpg',
  };
}

/// Narrow port for handing a card to the platform share sheet (§4.2,
/// business_logic.md §5). The shell builds the [ShareableCard] (resolving image
/// bytes through the attachment read port) and delegates the platform call here,
/// so the system-share dependency never leaks into the page or the shell.
abstract interface class CardShareRepository {
  Future<Result<void, CollectionFailure>> share(ShareableCard card);
}
