import 'dart:typed_data';

/// What the player is currently doing with the loaded clip. Emitted on [phases].
/// There is no `idle` member — "nothing loaded" is modelled one level up, by the
/// playback controller's snapshot, not by the port.
enum PlaybackPhase { loading, playing, paused, completed }

/// A position/duration sample for the clip in flight (emitted a few times a
/// second while playing). [duration] is [Duration.zero] until the decoder
/// reports the clip length.
class PlaybackProgress {
  const PlaybackProgress({required this.position, required this.duration});

  final Duration position;
  final Duration duration;
}

/// Narrow port over the platform audio player (spec §4.2 playback) — the twin of
/// [AudioRecorderPort]. Kept abstract so features depend on the intent ("play
/// this clip"), not on `package:audioplayers`, and tests can substitute a fake.
///
/// Stateful by nature: at most one clip is loaded at a time. The lifecycle is
/// [play] → (pause ⇄ resume | [seek])* → [stop]; calling [play] again replaces
/// the loaded clip. Position and phase are surfaced as streams the caller
/// subscribes to ([progress] / [phases]).
abstract class AudioPlayerPort {
  /// Load [bytes] (declared [mime]) and start playing from the beginning,
  /// replacing any clip already loaded.
  Future<void> play(Uint8List bytes, {required String mime});

  /// Pause the current clip, keeping its position so [resume] continues it.
  Future<void> pause();

  /// Resume a paused clip.
  Future<void> resume();

  /// Seek the current clip to [position].
  Future<void> seek(Duration position);

  /// Stop playback and release the current clip. A no-op if nothing is loaded.
  Future<void> stop();

  /// Position/duration samples for the current clip while it plays.
  Stream<PlaybackProgress> get progress;

  /// Phase transitions: playing ⇄ paused, and [PlaybackPhase.completed] when the
  /// clip reaches its end.
  Stream<PlaybackPhase> get phases;

  /// Release platform resources. The port is unusable afterwards.
  Future<void> dispose();
}
