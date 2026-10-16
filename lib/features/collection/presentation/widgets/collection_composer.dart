import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:knit/features/collection/presentation/collection_composer_state.dart';
import 'package:knit/l10n/app_localizations.dart';
import 'package:knit/features/collection/presentation/widgets/audio_record_bar.dart';
import 'package:knit/features/collection/presentation/widgets/composer_previews.dart';

class CollectionComposer extends StatelessWidget {
  const CollectionComposer({
    super.key,
    required this.controller,
    required this.pendingImageBytes,
    required this.pendingFileName,
    required this.showPhotoSources,
    required this.hasPendingAudio,
    required this.showAudioBar,
    required this.recordingPhase,
    required this.onSend,
    required this.onAddBlock,
    required this.onCancelPhotoSources,
    required this.onPickFromGallery,
    required this.onPickFromCamera,
    required this.onClearImage,
    required this.onClearFile,
    required this.onStartRecording,
    required this.onPauseRecording,
    required this.onResumeRecording,
    required this.onStopRecording,
    required this.onCancelAudio,
    required this.onClearAudio,
  });
  final TextEditingController controller;

  /// Bytes of an image the user picked but hasn't sent yet; null ⇒ no preview.
  final Uint8List? pendingImageBytes;

  /// Name of a file the user picked but hasn't sent yet; null ⇒ no preview.
  final String? pendingFileName;

  /// Whether the gallery/camera options row is shown above the input row.
  final bool showPhotoSources;

  /// Whether a recorded-but-unsent audio clip is staged (shows its preview chip).
  final bool hasPendingAudio;

  /// Whether the audio bar was revealed via "+" → Audio (the idle reveal).
  final bool showAudioBar;

  /// The live capture sub-state; non-null while recording/paused. Combined with
  /// [showAudioBar] it decides whether the recording bar is shown.
  final AudioRecordingPhase? recordingPhase;
  final VoidCallback onSend;
  final VoidCallback onAddBlock;

  /// Leave photo-source mode without picking (the "+" becomes a "✕" in mode).
  final VoidCallback onCancelPhotoSources;
  final VoidCallback onPickFromGallery;
  final VoidCallback onPickFromCamera;
  final VoidCallback onClearImage;
  final VoidCallback onClearFile;
  final VoidCallback onStartRecording;
  final VoidCallback onPauseRecording;
  final VoidCallback onResumeRecording;
  final VoidCallback onStopRecording;

  /// Back out of the audio bar (its "✕"), cancelling any in-flight recording.
  final VoidCallback onCancelAudio;
  final VoidCallback onClearAudio;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);
    final bytes = pendingImageBytes;
    // The audio bar shows while revealed-idle or actively recording (but not once
    // a clip is staged — its preview chip takes over). Modes are exclusive.
    final inAudioMode = recordingPhase != null || showAudioBar;
    final inPickerMode = showPhotoSources || inAudioMode;
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(8, 4, 8, 8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (bytes != null)
              PendingImagePreview(bytes: bytes, onClear: onClearImage),
            if (hasPendingAudio) PendingAudioPreview(onClear: onClearAudio),
            if (pendingFileName != null)
              PendingFilePreview(name: pendingFileName!, onClear: onClearFile),
            if (showPhotoSources)
              PhotoSourceOptions(
                onGallery: onPickFromGallery,
                onCamera: onPickFromCamera,
              ),
            if (inAudioMode)
              AudioRecordBar(
                phase: recordingPhase,
                onStart: onStartRecording,
                onPause: onPauseRecording,
                onResume: onResumeRecording,
                onStop: onStopRecording,
              ),
            Row(
              children: [
                // In a picker mode (photo sources or audio) the "+" becomes a
                // "✕" so the user can back out without committing.
                inPickerMode
                    ? IconButton(
                        tooltip: l10n.actionCancel,
                        icon: const Icon(Icons.close),
                        onPressed: showPhotoSources
                            ? onCancelPhotoSources
                            : onCancelAudio,
                      )
                    : IconButton(
                        tooltip: l10n.collectionAddBlockTooltip,
                        icon: const Icon(Icons.add_circle_outline),
                        onPressed: onAddBlock,
                      ),
                Expanded(
                  child: TextField(
                    controller: controller,
                    minLines: 1,
                    maxLines: 5,
                    keyboardType: TextInputType.multiline,
                    textInputAction: TextInputAction.newline,
                    decoration: InputDecoration(
                      hintText: l10n.collectionComposerHint,
                      filled: true,
                      fillColor: theme.colorScheme.surfaceContainerHighest,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(24),
                        borderSide: BorderSide.none,
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 8,
                      ),
                    ),
                  ),
                ),
                IconButton(
                  tooltip: l10n.collectionSendTooltip,
                  icon: const Icon(Icons.send),
                  onPressed: onSend,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
