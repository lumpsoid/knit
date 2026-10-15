import 'dart:io';

import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';
import 'package:knit/core/attachments/domain/audio_recorder_port.dart';
import 'package:knit/core/attachments/domain/picked_audio.dart';

/// [AudioRecorderPort] over `package:record`. Records AAC-LC into an `.m4a`
/// container in a private temp file, then reads the bytes back into memory on
/// [stop] so they can flow on to the hashing + content-addressed blob-store path
/// (spec §7.4.8) — exactly like a picked image. The temp file is deleted once
/// its bytes have been read; nothing unsigned outlives the capture.
class RecordAudioRecorder implements AudioRecorderPort {
  RecordAudioRecorder({AudioRecorder? recorder})
    : _recorder = recorder ?? AudioRecorder();

  final AudioRecorder _recorder;

  /// The MP4/AAC container `record` writes with [AudioEncoder.aacLc].
  static const String _mime = 'audio/mp4';

  @override
  Future<bool> start() async {
    if (!await _recorder.hasPermission()) return false;
    final dir = await getTemporaryDirectory();
    final stamp = DateTime.now().microsecondsSinceEpoch;
    final path = '${dir.path}/knit-recording-$stamp.m4a';
    await _recorder.start(
      const RecordConfig(encoder: AudioEncoder.aacLc),
      path: path,
    );
    return true;
  }

  @override
  Future<void> pause() => _recorder.pause();

  @override
  Future<void> resume() => _recorder.resume();

  @override
  Future<PickedAudio?> stop() async {
    final path = await _recorder.stop();
    if (path == null) return null;
    final file = File(path);
    if (!await file.exists()) return null;
    final bytes = await file.readAsBytes();
    // The bytes are now in memory bound for the blob store — drop the temp file.
    try {
      await file.delete();
    } catch (_) {
      // Best-effort cleanup; a lingering temp file is harmless.
    }
    return PickedAudio(bytes: bytes, mime: _mime);
  }

  @override
  Future<void> cancel() => _recorder.cancel();
}
