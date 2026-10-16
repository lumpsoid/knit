import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:logging/logging.dart';
import 'package:knit/core/attachments/domain/attachment_read_repository.dart';
import 'package:knit/core/attachments/domain/audio_player_port.dart';

/// The at-a-glance state of audio playback, shared by the Collection feed and
/// the Media overview: the mini-player bar and the now-playing card flip. [cardId] is the
/// feed card whose clip is loaded — null means nothing is playing (the bar is
/// hidden, no card is flipped). A widget-facing view-model: primitives only
/// (widgets.md §1), no sync-core type.
@immutable
class PlaybackSnapshot {
  const PlaybackSnapshot({
    this.cardId,
    this.phase = PlaybackPhase.completed,
    this.position = Duration.zero,
    this.duration = Duration.zero,
  });

  /// The playing feed card's id, or null when nothing is loaded.
  final String? cardId;
  final PlaybackPhase phase;
  final Duration position;
  final Duration duration;

  bool get isActive => cardId != null;
  bool get isPlaying => phase == PlaybackPhase.playing;
  bool get isLoading => phase == PlaybackPhase.loading;

  PlaybackSnapshot copyWith({
    PlaybackPhase? phase,
    Duration? position,
    Duration? duration,
  }) => PlaybackSnapshot(
    cardId: cardId,
    phase: phase ?? this.phase,
    position: position ?? this.position,
    duration: duration ?? this.duration,
  );
}

/// Owns the [AudioPlayerPort] and turns audio-card taps into playback, exposing
/// one [ValueListenable] the bar and the flipped card both watch. Kept *outside*
/// the Collection FCIS state holder on purpose: position ticks a few times a
/// second, and folding them into the feed's state would rebuild every card —
/// here only the bar and the single playing chip listen, so the feed is
/// untouched (the "dedicated controller" integration, mirroring the read-only
/// `sync_status` scope but with play/pause/seek/close intent).
class AudioPlaybackController {
  AudioPlaybackController({
    required AudioPlayerPort player,
    required AttachmentReadRepository attachmentRead,
    Logger? logger,
  }) : _player = player,
       _attachmentRead = attachmentRead,
       _log = logger ?? Logger('knit.audio_playback') {
    _progressSub = _player.progress.listen(_onProgress);
    _phaseSub = _player.phases.listen(_onPhase);
  }

  final AudioPlayerPort _player;
  final AttachmentReadRepository _attachmentRead;
  final Logger _log;

  final ValueNotifier<PlaybackSnapshot> _snapshot = ValueNotifier(
    const PlaybackSnapshot(),
  );

  late final StreamSubscription<PlaybackProgress> _progressSub;
  late final StreamSubscription<PlaybackPhase> _phaseSub;

  /// Monotonic guard so a slow byte-load can't clobber a newer tap.
  int _loadToken = 0;

  /// The loaded clip's bytes/mime, cached so replay-after-finish (and the bar's
  /// play button) needn't re-read the blob store.
  Uint8List? _bytes;
  String? _mime;

  /// What the bar and the feed watch.
  ValueListenable<PlaybackSnapshot> get snapshot => _snapshot;

  /// Tap an audio card: start it if it isn't the active clip; otherwise toggle
  /// play/pause (or replay if it had finished). [attachmentId] resolves the
  /// bytes via the read port.
  Future<void> toggle(String cardId, String attachmentId) async {
    final current = _snapshot.value;
    if (current.cardId != cardId) {
      await _start(cardId, attachmentId);
      return;
    }
    switch (current.phase) {
      case PlaybackPhase.playing:
        await _player.pause();
      case PlaybackPhase.paused:
        await _player.resume();
      case PlaybackPhase.completed:
        await _replay();
      case PlaybackPhase.loading:
        break;
    }
  }

  /// The bar's play/pause button — acts on whatever clip is loaded.
  Future<void> togglePlayPause() async {
    final current = _snapshot.value;
    if (current.cardId == null) return;
    switch (current.phase) {
      case PlaybackPhase.playing:
        await _player.pause();
      case PlaybackPhase.paused:
        await _player.resume();
      case PlaybackPhase.completed:
        await _replay();
      case PlaybackPhase.loading:
        break;
    }
  }

  Future<void> seek(Duration position) async {
    if (_snapshot.value.cardId == null) return;
    // Move the thumb immediately; the player echoes it back on the next tick.
    _snapshot.value = _snapshot.value.copyWith(position: position);
    await _player.seek(position);
  }

  /// The bar's ✕ — stop and clear (no card flipped, bar hidden).
  Future<void> close() async {
    _loadToken++;
    _bytes = null;
    _mime = null;
    _snapshot.value = const PlaybackSnapshot();
    await _player.stop();
  }

  Future<void> _start(String cardId, String attachmentId) async {
    final token = ++_loadToken;
    _snapshot.value = PlaybackSnapshot(
      cardId: cardId,
      phase: PlaybackPhase.loading,
    );
    final result = await _attachmentRead.bytesOf(attachmentId);
    if (token != _loadToken) return; // superseded by a newer tap
    if (result.isFailure) {
      _log.warning('Audio bytes missing for $attachmentId');
      _snapshot.value = const PlaybackSnapshot();
      return;
    }
    final audio = result.getOrThrow();
    _bytes = audio.bytes;
    _mime = audio.mime;
    try {
      await _player.play(audio.bytes, mime: audio.mime);
    } catch (e, s) {
      _log.severe('Audio play failed', e, s);
      if (token == _loadToken) _snapshot.value = const PlaybackSnapshot();
    }
  }

  /// Replay the cached clip from the start (after it finished, or from the bar).
  Future<void> _replay() async {
    final bytes = _bytes, mime = _mime;
    if (bytes == null || mime == null) return;
    try {
      await _player.play(bytes, mime: mime);
    } catch (e, s) {
      _log.severe('Audio replay failed', e, s);
    }
  }

  void _onProgress(PlaybackProgress p) {
    final s = _snapshot.value;
    if (s.cardId == null) return;
    _snapshot.value = s.copyWith(position: p.position, duration: p.duration);
  }

  void _onPhase(PlaybackPhase phase) {
    final s = _snapshot.value;
    if (s.cardId == null) return;
    // On completion keep the card bound but rewind to zero, so the bar stays put
    // and offers a replay rather than vanishing mid-scroll.
    if (phase == PlaybackPhase.completed) {
      _snapshot.value = s.copyWith(
        phase: PlaybackPhase.completed,
        position: Duration.zero,
      );
      return;
    }
    _snapshot.value = s.copyWith(phase: phase);
  }

  Future<void> dispose() async {
    await _progressSub.cancel();
    await _phaseSub.cancel();
    _snapshot.dispose();
    await _player.dispose();
  }
}
