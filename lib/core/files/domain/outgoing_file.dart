import 'dart:typed_data';

/// A finished file ready to hand to the OS share sheet or a save dialog: the
/// [bytes], the suggested [fileName] (with its [extension]) and its
/// [mimeType].
class OutgoingFile {
  const OutgoingFile({
    required this.bytes,
    required this.fileName,
    required this.mimeType,
    required this.extension,
  });

  final Uint8List bytes;
  final String fileName;
  final String mimeType;

  /// Without the dot, e.g. `zip`.
  final String extension;
}
