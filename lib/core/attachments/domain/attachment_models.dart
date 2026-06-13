import 'dart:typed_data';

/// The bytes of a stored attachment plus enough to render them (its [mime]).
/// A read model handed to the UI — primitives only (widgets.md §1), so the
/// render widget never sees a [Snapshot] or any sync domain type.
class AttachmentBytes {
  const AttachmentBytes({required this.bytes, required this.mime});

  final Uint8List bytes;
  final String mime;
}
