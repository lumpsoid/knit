import 'dart:async';
import 'dart:typed_data';

import 'package:audioplayers/audioplayers.dart';
import 'package:knit/core/attachments/domain/audio_player_port.dart';

/// [AudioPlayerPort] over `package:audioplayers`. Plays the in-memory clip bytes
/// directly via [BytesSource] — the playback twin of [RecordAudioRecorder],
/// matching the content-addressed model where attachment bytes ride in memory
/// (spec §7.4.8) rather than living at a stable path.
///
/// The package exposes position, duration, state and completion as separate
/// streams; this adapter folds position+duration into one [PlaybackProgress]
/// stream (caching the last value of each) and maps player states onto
/// [PlaybackPhase], emitting [PlaybackPhase.completed] when the clip ends.
class AudioPlayersAudioPlayer implements AudioPlayerPort {
  AudioPlayersAudioPlayer({AudioPlayer? player})
    : _player = player ?? AudioPlayer() {
    _subs = [
      _player.onPositionChanged.listen((pos) {
        _position = pos;
        _emitProgress();
      }),
      _player.onDurationChanged.listen((dur) {
        _duration = dur;
        _emitProgress();
      }),
      _player.onPlayerStateChanged.listen((state) {
        switch (state) {
          case PlayerState.playing:
            _phases.add(PlaybackPhase.playing);
          case PlayerState.paused:
            _phases.add(PlaybackPhase.paused);
          // Completion resets position too, so it's handled via onPlayerComplete;
          // stopped/disposed are caller-driven and carry no phase of their own.
          case PlayerState.completed:
          case PlayerState.stopped:
          case PlayerState.disposed:
            break;
        }
      }),
      _player.onPlayerComplete.listen((_) {
        _position = Duration.zero;
        _phases.add(PlaybackPhase.completed);
      }),
    ];
  }

  final AudioPlayer _player;
  final StreamController<PlaybackProgress> _progress =
      StreamController<PlaybackProgress>.broadcast();
  final StreamController<PlaybackPhase> _phases =
      StreamController<PlaybackPhase>.broadcast();
  late final List<StreamSubscription<Object?>> _subs;

  Duration _position = Duration.zero;
  Duration _duration = Duration.zero;

  void _emitProgress() =>
      _progress.add(PlaybackProgress(position: _position, duration: _duration));

  @override
  Stream<PlaybackProgress> get progress => _progress.stream;

  @override
  Stream<PlaybackPhase> get phases => _phases.stream;

  @override
  Future<void> play(Uint8List bytes, {required String mime}) async {
    _position = Duration.zero;
    _duration = Duration.zero;
    await _player.play(BytesSource(bytes, mimeType: mime));
  }

  @override
  Future<void> pause() => _player.pause();

  @override
  Future<void> resume() => _player.resume();

  @override
  Future<void> seek(Duration position) => _player.seek(position);

  @override
  Future<void> stop() => _player.stop();

  @override
  Future<void> dispose() async {
    for (final sub in _subs) {
      await sub.cancel();
    }
    await _progress.close();
    await _phases.close();
    await _player.dispose();
  }
}
