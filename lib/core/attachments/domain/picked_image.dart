import 'dart:typed_data';

/// An image the user just picked, held in memory before it is hashed and stored
/// (spec §6.4/§7.4.8). The bytes are the raw file contents; [mime] is the
/// declared media type (e.g. `image/png`). This is a widget-/picker-agnostic
/// value so the [ImagePickerPort] stays mockable in tests.
class PickedImage {
  const PickedImage({required this.bytes, required this.mime});

  final Uint8List bytes;
  final String mime;
}
