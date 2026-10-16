import 'dart:async';

import 'package:logging/logging.dart';
import 'package:knit/core/attachments/domain/audio_recorder_port.dart';
import 'package:knit/core/attachments/domain/file_picker_port.dart';
import 'package:knit/core/attachments/domain/image_picker_port.dart';
import 'package:knit/core/attachments/domain/picked_audio.dart';
import 'package:knit/features/collection/presentation/collection_action.dart';
import 'package:knit/features/collection/presentation/collection_composer_state.dart';
import 'package:knit/features/collection/presentation/collection_ui_effect.dart';

/// The Collection composer's input object (§4.2): stages a picked image, a
/// recorded clip, or a picked file in [state] while the user writes a caption,
/// drives the recorder, and hands a send to the Collection through [onSend].
///
/// One per Collection page — the [CollectionController] builds it with the
/// page's ports and disposes it with the page.
class CollectionComposerController {
  CollectionComposerController({
    required ImagePickerPort imagePicker,
    required AudioRecorderPort audioRecorder,
    required FilePickerPort filePicker,
    required void Function(ComposerSubmitted send) onSend,
    required void Function(CollectionMessage message) onMessage,
    Logger? logger,
  }) : _imagePicker = imagePicker,
       _recorder = audioRecorder,
       _filePicker = filePicker,
       _onSend = onSend,
       _onMessage = onMessage,
       _log = logger ?? Logger('knit.collection');

  final ImagePickerPort _imagePicker;
  final AudioRecorderPort _recorder;
  final FilePickerPort _filePicker;
  final void Function(ComposerSubmitted send) _onSend;
  final void Function(CollectionMessage message) _onMessage;
  final Logger _log;

  final CollectionComposerState state = CollectionComposerState();

  /// Set once the page is gone: a pick or recorder call still in flight then
  /// lands on nothing.
  bool _disposed = false;

  /// Send [text] with whatever is staged. Returns false (and sends nothing)
  /// when the send wouldn't go through, so the page keeps the typed text.
  bool submit(String text) {
    if (!state.canSend(text)) return false;
    _onSend(state.takeSubmission(text));
    return true;
  }

  // --- photo -----------------------------------------------------------------

  /// "+" → Photo: show the gallery/camera options above the input row.
  void showPhotoSources() => state.showPanel(ComposerPanel.photoSources);

  /// Leave the photo options without picking (the "✕" the "+" turns into).
  void closePhotoSources() => state.showPanel(ComposerPanel.none);

  /// A source was chosen: hide the options and stage the picked image (a
  /// cancelled pick changes nothing).
  Future<void> pickImage(ImagePickerSource source) async {
    state.showPanel(ComposerPanel.none);
    final picked = await _imagePicker.pickImage(source: source);
    if (_disposed || picked == null) return;
    state.stageImage(picked);
  }

  void clearImage() => state.clearImage();

  // --- file ------------------------------------------------------------------

  /// "+" → File: open the platform picker and stage the chosen file.
  Future<void> pickFile() async {
    final picked = await _filePicker.pickFile();
    if (_disposed || picked == null) return;
    state.stageFile(picked);
  }

  void clearFile() => state.clearFile();

  // --- audio -----------------------------------------------------------------

  /// "+" → Audio: show the recording bar, idle until the user starts.
  void showAudioBar() => state.showPanel(ComposerPanel.audioBar);

  /// Begin capturing. The phase is staged only once the recorder confirms it
  /// started; a denied microphone permission (or an error) says why and leaves
  /// the bar idle.
  Future<void> startRecording() async {
    try {
      final started = await _recorder.start();
      if (_disposed) {
        if (started) await _safeRecorder(_recorder.cancel, 'cancel recording');
        return;
      }
      if (started) {
        state.setRecordingPhase(AudioRecordingPhase.recording);
      } else {
        _onMessage(CollectionMessage.micPermissionDenied);
        state.setRecordingPhase(null);
      }
    } catch (e, s) {
      _log.severe('Start audio recording failed', e, s);
      if (_disposed) return;
      _onMessage(CollectionMessage.saveFailed);
      state.setRecordingPhase(null);
    }
  }

  /// Pause/Resume flip the phase optimistically, then tell the recorder; a
  /// recorder failure is logged only.
  Future<void> pauseRecording() async {
    state.setRecordingPhase(AudioRecordingPhase.paused);
    await _safeRecorder(_recorder.pause, 'pause recording');
  }

  Future<void> resumeRecording() async {
    state.setRecordingPhase(AudioRecordingPhase.recording);
    await _safeRecorder(_recorder.resume, 'resume recording');
  }

  /// Stop capturing: hide the bar now and stage the clip once the recorder hands
  /// it back (nothing captured, or a failure, just leaves recording mode). The
  /// bar stays up until then, since the phase is still set.
  Future<void> stopRecording() async {
    state.showPanel(ComposerPanel.none);
    PickedAudio? audio;
    try {
      audio = await _recorder.stop();
    } catch (e, s) {
      _log.severe('Stop audio recording failed', e, s);
      if (!_disposed) _onMessage(CollectionMessage.saveFailed);
      audio = null;
    }
    if (_disposed) return;
    state.finishRecording(audio);
  }

  /// Back out of the audio bar (its "✕"): hide it, and discard an in-flight
  /// recording if one is running.
  Future<void> closeAudioBar() async {
    final recording = state.isRecordingAudio;
    state.showPanel(ComposerPanel.none);
    if (!recording) return;
    state.discardRecording();
    await _safeRecorder(_recorder.cancel, 'cancel recording');
  }

  void clearAudio() => state.clearAudio();

  Future<void> _safeRecorder(Future<void> Function() op, String label) async {
    try {
      await op();
    } catch (e, s) {
      _log.severe('Audio $label failed', e, s);
    }
  }

  /// The page left: release the recorder if it is still capturing, and drop
  /// the state.
  void dispose() {
    _disposed = true;
    if (state.isRecordingAudio) {
      unawaited(_safeRecorder(_recorder.cancel, 'cancel recording'));
    }
    state.dispose();
  }
}
