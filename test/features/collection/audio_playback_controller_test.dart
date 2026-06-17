import 'dart:async';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:knit/core/attachments/domain/attachment_failure.dart';
import 'package:knit/core/attachments/domain/attachment_models.dart';
import 'package:knit/core/attachments/domain/attachment_read_repository.dart';
import 'package:knit/core/attachments/domain/audio_player_port.dart';
import 'package:knit/features/collection/presentation/audio_playback_controller.dart';
import 'package:result_dart/result_dart.dart';

/// A scriptable [AudioPlayerPort]: records the calls it received and lets the
/// test drive the position/phase streams the platform player would emit.
class _FakePlayer implements AudioPlayerPort {
  final _progress = StreamController<PlaybackProgress>.broadcast();
  final _phases = StreamController<PlaybackPhase>.broadcast();
  final List<String> calls = <String>[];
  Uint8List? lastBytes;

  @override
  Stream<PlaybackProgress> get progress => _progress.stream;
  @override
  Stream<PlaybackPhase> get phases => _phases.stream;

  @override
  Future<void> play(Uint8List bytes, {required String mime}) async {
    calls.add('play');
    lastBytes = bytes;
  }

  @override
  Future<void> pause() async => calls.add('pause');
  @override
  Future<void> resume() async => calls.add('resume');
  @override
  Future<void> seek(Duration position) async => calls.add('seek:$position');
  @override
  Future<void> stop() async => calls.add('stop');
  @override
  Future<void> dispose() async {
    await _progress.close();
    await _phases.close();
  }

  void emitPhase(PlaybackPhase phase) => _phases.add(phase);
  void emitProgress(Duration position, Duration duration) =>
      _progress.add(PlaybackProgress(position: position, duration: duration));
}

/// A read port that returns a fixed result and counts how often it's hit (to
/// prove a replay doesn't re-read the blob store).
class _FakeRead implements AttachmentReadRepository {
  _FakeRead(this._result);
  final Result<AttachmentBytes, AttachmentFailure> _result;
  int calls = 0;

  @override
  Future<Result<AttachmentBytes, AttachmentFailure>> bytesOf(String id) async {
    calls++;
    return _result;
  }
}

void main() {
  final clip = AttachmentBytes(
    bytes: Uint8List.fromList([1, 2, 3]),
    mime: 'audio/mp4',
  );
  late _FakePlayer player;

  AudioPlaybackController controllerWith(
    Result<AttachmentBytes, AttachmentFailure> result,
  ) {
    player = _FakePlayer();
    return AudioPlaybackController(
      player: player,
      attachmentRead: _FakeRead(result),
    );
  }

  test('toggle a fresh card loads its bytes and plays', () async {
    final c = controllerWith(Ok(clip));
    await c.toggle('c1', 'a1');

    expect(c.snapshot.value.cardId, 'c1');
    expect(c.snapshot.value.isLoading, isTrue);
    expect(player.calls, ['play']);
    expect(player.lastBytes, clip.bytes);
  });

  test('a phase emission flips the snapshot to playing', () async {
    final c = controllerWith(Ok(clip));
    await c.toggle('c1', 'a1');
    player.emitPhase(PlaybackPhase.playing);
    await pumpEventQueue();

    expect(c.snapshot.value.isPlaying, isTrue);
  });

  test('toggling the active card pauses, then resumes', () async {
    final c = controllerWith(Ok(clip));
    await c.toggle('c1', 'a1');
    player.emitPhase(PlaybackPhase.playing);
    await pumpEventQueue();

    await c.toggle('c1', 'a1'); // playing → pause
    expect(player.calls.last, 'pause');
    player.emitPhase(PlaybackPhase.paused);
    await pumpEventQueue();

    await c.toggle('c1', 'a1'); // paused → resume
    expect(player.calls.last, 'resume');
  });

  test('progress samples update position and duration', () async {
    final c = controllerWith(Ok(clip));
    await c.toggle('c1', 'a1');
    player.emitProgress(const Duration(seconds: 2), const Duration(seconds: 9));
    await pumpEventQueue();

    expect(c.snapshot.value.position, const Duration(seconds: 2));
    expect(c.snapshot.value.duration, const Duration(seconds: 9));
  });

  test('completion keeps the card bound but rewinds to zero', () async {
    final c = controllerWith(Ok(clip));
    await c.toggle('c1', 'a1');
    player.emitProgress(const Duration(seconds: 5), const Duration(seconds: 5));
    await pumpEventQueue();
    player.emitPhase(PlaybackPhase.completed);
    await pumpEventQueue();

    expect(c.snapshot.value.cardId, 'c1', reason: 'bar stays, not dismissed');
    expect(c.snapshot.value.phase, PlaybackPhase.completed);
    expect(c.snapshot.value.position, Duration.zero);
  });

  test('replay after completion reuses cached bytes (no second read)', () async {
    final read = _FakeRead(Ok(clip));
    player = _FakePlayer();
    final c = AudioPlaybackController(player: player, attachmentRead: read);
    await c.toggle('c1', 'a1');
    player.emitPhase(PlaybackPhase.completed);
    await pumpEventQueue();

    await c.toggle('c1', 'a1'); // completed → replay
    expect(player.calls, ['play', 'play']);
    expect(read.calls, 1, reason: 'replay must not re-read the blob store');
  });

  test('close stops playback and clears the snapshot', () async {
    final c = controllerWith(Ok(clip));
    await c.toggle('c1', 'a1');
    await c.close();

    expect(c.snapshot.value.isActive, isFalse);
    expect(player.calls.last, 'stop');
  });

  test('missing bytes leave nothing playing', () async {
    final c = controllerWith(Failure(const AttachmentBytesMissing('h')));
    await c.toggle('c1', 'a1');

    expect(c.snapshot.value.isActive, isFalse);
    expect(player.calls, isEmpty, reason: 'never reached play()');
  });
}
