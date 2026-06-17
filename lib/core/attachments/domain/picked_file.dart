import 'dart:typed_data';

/// A file the user just picked, held in memory before it is hashed and stored
/// (spec §6.4/§7.4.8). The bytes are the raw file contents; [mime] is the
/// declared media type (derived from the extension when the picker doesn't
/// surface one); [name] is the original file name, preserved on the stored
/// `attachment` record so the file card can label it and sharing keeps it. This
/// is a widget-/picker-agnostic value so the [FilePickerPort] stays mockable in
/// tests — the file twin of [PickedImage]/[PickedAudio].
class PickedFile {
  const PickedFile({
    required this.bytes,
    required this.mime,
    required this.name,
  });

  final Uint8List bytes;
  final String mime;
  final String name;
}
