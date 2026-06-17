import 'dart:typed_data';

/// The bytes of a stored attachment plus enough to render/label them (its
/// [mime], and for file attachments its original [name] and byte [size], §7.4.8).
/// A read model handed to the UI — primitives only (widgets.md §1), so the
/// render widget never sees a [Snapshot] or any sync domain type.
class AttachmentBytes {
  const AttachmentBytes({
    required this.bytes,
    required this.mime,
    this.name,
    this.size,
  });

  final Uint8List bytes;
  final String mime;

  /// The attachment's original file name (§7.4.8), when it has one — file
  /// attachments keep it; null for an image/audio captured in-app.
  final String? name;

  /// The stored byte size (§7.4.8), for labelling a file chip; null when absent.
  final int? size;
}
