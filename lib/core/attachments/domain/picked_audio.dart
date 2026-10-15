import 'dart:typed_data';

/// An audio message the user just recorded, held in memory before it is hashed
/// and stored (spec §6.4/§7.4.8). The bytes are the raw recording file contents;
/// [mime] is the declared media type (e.g. `audio/mp4`). This is a
/// widget-/recorder-agnostic value so the [AudioRecorderPort] stays mockable in
/// tests — the audio twin of [PickedImage].
class PickedAudio {
  const PickedAudio({required this.bytes, required this.mime, this.name});

  final Uint8List bytes;
  final String mime;

  /// The original file name when the audio was picked from disk (§7.4.8); null
  /// for an in-app recording, which has no name of its own.
  final String? name;
}
