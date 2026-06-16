import 'dart:typed_data';

/// An audio message the user just recorded, held in memory before it is hashed
/// and stored (spec §6.4/§7.4.8). The bytes are the raw recording file contents;
/// [mime] is the declared media type (e.g. `audio/mp4`). This is a
/// widget-/recorder-agnostic value so the [AudioRecorderPort] stays mockable in
/// tests — the audio twin of [PickedImage].
class PickedAudio {
  const PickedAudio({required this.bytes, required this.mime});

  final Uint8List bytes;
  final String mime;
}
