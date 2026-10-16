import 'package:flutter/material.dart';
import 'package:knit/core/attachments/domain/audio_player_port.dart';
import 'package:knit/l10n/app_localizations.dart';

/// The persistent audio player pinned above the composer (§4.2) — the playback
/// twin of the recording bar, sharing its container (surfaceContainerHighest,
/// 16-radius) so playing and recording read as the same surface. It stays on
/// screen while the feed scrolls so the user never loses what's playing: a
/// play/pause button, the elapsed time, a seekable progress bar showing where we
/// are now, the total length, and a ✕ to dismiss.
///
/// Primitives only (widgets.md §1): it's handed the current phase/position/
/// duration and three callbacks; the [AudioPlaybackController] owns the state and
/// the player.
class AudioMiniPlayer extends StatelessWidget {
  const AudioMiniPlayer({
    super.key,
    required this.phase,
    required this.position,
    required this.duration,
    required this.onPlayPause,
    required this.onSeek,
    required this.onClose,
  });

  final PlaybackPhase phase;
  final Duration position;
  final Duration duration;
  final VoidCallback onPlayPause;
  final ValueChanged<Duration> onSeek;
  final VoidCallback onClose;

  static String _format(Duration d) {
    final minutes = d.inMinutes;
    final seconds = d.inSeconds % 60;
    return '$minutes:${seconds.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);
    final playing = phase == PlaybackPhase.playing;
    final loading = phase == PlaybackPhase.loading;
    final totalMs = duration.inMilliseconds;
    final knowsDuration = totalMs > 0;
    // Clamp so a position sample that arrives a tick ahead of the duration can't
    // push the slider past its max (a runtime assert).
    final value = knowsDuration
        ? position.inMilliseconds.clamp(0, totalMs).toDouble()
        : 0.0;
    final timeStyle = theme.textTheme.bodyMedium?.copyWith(
      fontFeatures: const [FontFeature.tabularFigures()],
    );
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 4, 8, 8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: theme.colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          children: [
            if (loading)
              const SizedBox(
                width: 48,
                height: 48,
                child: Padding(
                  padding: EdgeInsets.all(14),
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              )
            else
              IconButton(
                tooltip: playing
                    ? l10n.collectionAudioPause
                    : l10n.collectionAudioPlay,
                icon: Icon(playing ? Icons.pause : Icons.play_arrow),
                onPressed: onPlayPause,
              ),
            Text(_format(position), style: timeStyle),
            Expanded(
              child: Slider(
                value: value,
                max: knowsDuration ? totalMs.toDouble() : 1,
                onChanged: knowsDuration
                    ? (v) => onSeek(Duration(milliseconds: v.round()))
                    : null,
              ),
            ),
            Text(_format(duration), style: timeStyle),
            IconButton(
              tooltip: l10n.actionClose,
              icon: const Icon(Icons.close),
              onPressed: onClose,
            ),
          ],
        ),
      ),
    );
  }
}
