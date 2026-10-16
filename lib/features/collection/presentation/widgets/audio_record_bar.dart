import 'dart:async';

import 'package:flutter/material.dart';
import 'package:knit/features/collection/presentation/collection_composer_state.dart';
import 'package:knit/l10n/app_localizations.dart';

/// The inline audio-recording bar shown above the composer (§4.2). Idle (no
/// [phase]) it offers "Start recording"; while capturing it shows a live
/// indicator — a pulsing dot, an elapsing timer, and a status label — plus
/// Pause/Resume and Stop. Owns its own ticker + pulse (pure View concerns); the
/// logical phase is driven from state via [phase].
class AudioRecordBar extends StatefulWidget {
  const AudioRecordBar({
    super.key,
    required this.phase,
    required this.onStart,
    required this.onPause,
    required this.onResume,
    required this.onStop,
  });

  /// Null ⇒ idle (revealed, not yet recording).
  final AudioRecordingPhase? phase;
  final VoidCallback onStart;
  final VoidCallback onPause;
  final VoidCallback onResume;
  final VoidCallback onStop;

  @override
  State<AudioRecordBar> createState() => _AudioRecordBarState();
}

class _AudioRecordBarState extends State<AudioRecordBar>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulse = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 700),
  );

  /// Ticks once a second while recording; cancelled (freezing the display) while
  /// paused or idle.
  Timer? _ticker;
  Duration _elapsed = Duration.zero;

  @override
  void initState() {
    super.initState();
    if (widget.phase == AudioRecordingPhase.recording) _sync();
  }

  @override
  void didUpdateWidget(AudioRecordBar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.phase == widget.phase) return;
    // A fresh recording (from idle) restarts the clock at zero; resuming from a
    // pause keeps the accumulated time.
    if (widget.phase == AudioRecordingPhase.recording &&
        oldWidget.phase != AudioRecordingPhase.paused) {
      _elapsed = Duration.zero;
    }
    _sync();
  }

  /// Reconcile the ticker + pulse with the current [widget.phase].
  void _sync() {
    if (widget.phase == AudioRecordingPhase.recording) {
      _ticker ??= Timer.periodic(const Duration(seconds: 1), (_) {
        setState(() => _elapsed += const Duration(seconds: 1));
      });
      if (!_pulse.isAnimating) _pulse.repeat(reverse: true);
    } else {
      _ticker?.cancel();
      _ticker = null;
      _pulse.stop();
    }
  }

  @override
  void dispose() {
    _ticker?.cancel();
    _pulse.dispose();
    super.dispose();
  }

  static String _format(Duration d) {
    final minutes = d.inMinutes;
    final seconds = d.inSeconds % 60;
    return '$minutes:${seconds.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);
    final phase = widget.phase;
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 4, 8, 8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: theme.colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(16),
        ),
        child: phase == null
            ? _idle(theme, l10n)
            : _recording(theme, l10n, phase),
      ),
    );
  }

  Widget _idle(ThemeData theme, AppLocalizations l10n) => Row(
    children: [
      const SizedBox(width: 8),
      Icon(Icons.mic_none, color: theme.colorScheme.primary),
      const SizedBox(width: 10),
      Expanded(child: Text(l10n.collectionAudioMessage)),
      TextButton.icon(
        onPressed: widget.onStart,
        icon: const Icon(Icons.fiber_manual_record, color: Color(0xFFE53935)),
        label: Text(l10n.collectionAudioStart),
      ),
    ],
  );

  Widget _recording(
    ThemeData theme,
    AppLocalizations l10n,
    AudioRecordingPhase phase,
  ) {
    final recording = phase == AudioRecordingPhase.recording;
    return Row(
      children: [
        const SizedBox(width: 8),
        _PulsingDot(animation: _pulse, active: recording),
        const SizedBox(width: 10),
        Text(
          _format(_elapsed),
          style: theme.textTheme.titleMedium?.copyWith(
            fontFeatures: const [FontFeature.tabularFigures()],
          ),
        ),
        const SizedBox(width: 10),
        Text(
          recording
              ? l10n.collectionAudioRecording
              : l10n.collectionAudioPaused,
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        const Spacer(),
        IconButton(
          tooltip: recording
              ? l10n.collectionAudioPause
              : l10n.collectionAudioResume,
          icon: Icon(recording ? Icons.pause : Icons.play_arrow),
          onPressed: recording ? widget.onPause : widget.onResume,
        ),
        IconButton.filledTonal(
          tooltip: l10n.collectionAudioStop,
          icon: const Icon(Icons.stop),
          onPressed: widget.onStop,
        ),
      ],
    );
  }
}

/// A small dot that pulses (fades in/out) while [active], or sits dimmed and
/// still when paused — the at-a-glance "recording is happening" cue (§4.2).
class _PulsingDot extends StatelessWidget {
  const _PulsingDot({required this.animation, required this.active});
  final Animation<double> animation;
  final bool active;

  static const Color _color = Color(0xFFE53935); // red 600

  @override
  Widget build(BuildContext context) {
    const dot = SizedBox(
      width: 12,
      height: 12,
      child: DecoratedBox(
        decoration: BoxDecoration(color: _color, shape: BoxShape.circle),
      ),
    );
    if (!active) {
      return Opacity(opacity: 0.4, child: dot);
    }
    return FadeTransition(
      opacity: Tween<double>(begin: 1, end: 0.25).animate(animation),
      child: dot,
    );
  }
}
