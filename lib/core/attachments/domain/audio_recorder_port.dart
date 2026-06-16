import 'package:knit/core/attachments/domain/picked_audio.dart';

/// Narrow port over the platform audio recorder (spec §4.2 capture step), kept
/// abstract so features depend on the intent ("record an audio message"), not on
/// `package:record`, and tests can substitute a fake.
///
/// Stateful by nature: at most one recording is in flight at a time. The
/// lifecycle is start → (pause ⇄ resume)* → stop|cancel. [start] obtains the
/// recording resource; [stop] yields the captured bytes; [cancel] discards an
/// in-flight recording without producing anything.
abstract class AudioRecorderPort {
  /// Begin recording to a fresh, private temp location. Returns `false` when
  /// microphone permission was denied (the caller surfaces that); throws only on
  /// an unexpected platform error.
  Future<bool> start();

  /// Pause the in-flight recording, keeping what was captured so [resume] can
  /// continue it.
  Future<void> pause();

  /// Resume a paused recording.
  Future<void> resume();

  /// Stop recording and return the captured audio, or `null` if nothing was
  /// recorded. The temp file is consumed — the bytes ride home in [PickedAudio].
  Future<PickedAudio?> stop();

  /// Discard an in-flight recording without producing audio (the user backed
  /// out). A no-op if nothing is recording.
  Future<void> cancel();
}
