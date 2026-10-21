import 'package:flutter/foundation.dart';
import 'package:knit/core/attachments/domain/image_optimization.dart';
import 'package:knit/core/attachments/domain/picked_audio.dart';
import 'package:knit/core/attachments/domain/picked_file.dart';
import 'package:knit/core/attachments/domain/picked_image.dart';
import 'package:knit/features/collection/presentation/collection_action.dart';

/// Whether an audio message is actively being captured, and if so its sub-state
/// (§4.2). Null (the field is nullable) ⇒ no recording in flight: either the bar
/// is idle/hidden or a recorded clip is already staged as the pending audio.
enum AudioRecordingPhase { recording, paused }

/// The inline panel the composer shows above its input row: the gallery/camera
/// options ("+" → Photo) or the audio-recording bar ("+" → Audio). Exclusive.
enum ComposerPanel { none, photoSources, audioBar }

/// The Collection composer's state (§4.2) — a [ChangeNotifier] the
/// [CollectionComposerController] owns and mutates, and the page listens to.
///
/// Holds what the user is composing but hasn't sent: a picked image, a recorded
/// clip, or a picked file (in memory only — nothing is stored or attached to a
/// card until the composer is sent), the live recording phase, and which inline
/// panel is open. The composer's text stays in the page's text field.
class CollectionComposerState extends ChangeNotifier {
  PickedImage? _pendingImage;
  PickedAudio? _pendingAudio;
  PickedFile? _pendingFile;
  AudioRecordingPhase? _recordingPhase;
  ComposerPanel _panel = ComposerPanel.none;
  bool _optimizeImages = false;
  PickedImage? _optimizedImage;
  bool _optimizingImage = false;
  bool _imageAlreadySmall = false;

  /// A picked image, shown as a preview above the input field. Clearing or
  /// repicking just drops these bytes — no attachment is written.
  PickedImage? get pendingImage => _pendingImage;

  /// A recorded clip — the audio twin of [pendingImage], shown as a chip.
  PickedAudio? get pendingAudio => _pendingAudio;

  /// A picked file — the file twin of [pendingImage], shown by its name.
  PickedFile? get pendingFile => _pendingFile;

  /// The live audio-capture sub-state: non-null while recording or paused. Null
  /// once stopped — the captured clip then lives in [pendingAudio].
  AudioRecordingPhase? get recordingPhase => _recordingPhase;

  /// Whether the user chose "Optimise size" for photos. It stays on for the
  /// next photo picked on this page.
  bool get optimizeImages => _optimizeImages;

  /// The smaller copy of [pendingImage], once optimised. Sent in its place
  /// while [optimizeImages] is on.
  PickedImage? get optimizedImage => _optimizedImage;

  /// The optimiser is working on [pendingImage]; a send waits for it.
  bool get optimizingImage => _optimizingImage;

  /// Optimising [pendingImage] would not make it meaningfully smaller (or it
  /// couldn't be read), so the original is sent.
  bool get imageAlreadySmall => _imageAlreadySmall;

  /// Whether [pendingImage] is a format "Optimise size" can work on.
  bool get canOptimizePendingImage {
    final image = _pendingImage;
    return image != null && ImageOptimization.canOptimize(image.mime);
  }

  /// Whether the optimiser still has to run on [pendingImage].
  bool get needsOptimizing =>
      _optimizeImages &&
      canOptimizePendingImage &&
      _optimizedImage == null &&
      !_optimizingImage &&
      !_imageAlreadySmall;

  ComposerPanel get panel => _panel;
  bool get showPhotoSources => _panel == ComposerPanel.photoSources;

  /// Whether the audio bar was revealed via "+" → Audio (the idle reveal). The
  /// bar also stays up while [recordingPhase] is set.
  bool get showAudioBar => _panel == ComposerPanel.audioBar;

  /// Whether an audio recording is actively being captured (not merely staged).
  bool get isRecordingAudio => _recordingPhase != null;

  /// Whether a send with [text] goes through: never while a recording is in
  /// flight (the user stops it first); otherwise a non-blank [text] or a staged
  /// image, clip, or file (which makes an empty caption a valid send).
  bool canSend(String text) =>
      !isRecordingAudio &&
      !_optimizingImage &&
      (text.trim().isNotEmpty ||
          _pendingImage != null ||
          _pendingAudio != null ||
          _pendingFile != null);

  /// Build the send for [text] and drop what it carries, closing any panel.
  /// One attachment rides per send — an image wins, then a file, then a clip;
  /// whatever else is staged stays for the next send. Call only when
  /// [canSend] holds. An optimised photo goes in place of its original.
  ComposerSubmitted takeSubmission(String text) {
    final picked = _pendingImage;
    final image = picked == null
        ? null
        : (_optimizeImages ? _optimizedImage : null) ?? picked;
    final file = image == null ? _pendingFile : null;
    final audio = image == null && file == null ? _pendingAudio : null;
    if (image != null) _dropImage();
    if (file != null) _pendingFile = null;
    if (audio != null) _pendingAudio = null;
    _panel = ComposerPanel.none;
    notifyListeners();
    return ComposerSubmitted(text, image: image, file: file, audio: audio);
  }

  void showPanel(ComposerPanel panel) {
    if (panel == _panel) return;
    _panel = panel;
    notifyListeners();
  }

  void stageImage(PickedImage image) {
    _dropImage();
    _pendingImage = image;
    notifyListeners();
  }

  void clearImage() {
    _dropImage();
    notifyListeners();
  }

  void setOptimizeImages(bool optimize) {
    if (optimize == _optimizeImages) return;
    _optimizeImages = optimize;
    notifyListeners();
  }

  void startOptimizing() {
    _optimizingImage = true;
    notifyListeners();
  }

  /// The optimiser finished on [source]: keep the smaller [optimized] copy, or
  /// note that there was nothing to gain (null). Ignored when [source] is no
  /// longer the staged photo.
  void finishOptimizing(PickedImage source, PickedImage? optimized) {
    if (!identical(source, _pendingImage)) return;
    _optimizingImage = false;
    _optimizedImage = optimized;
    _imageAlreadySmall = optimized == null;
    notifyListeners();
  }

  void _dropImage() {
    _pendingImage = null;
    _optimizedImage = null;
    _optimizingImage = false;
    _imageAlreadySmall = false;
  }

  void stageFile(PickedFile file) {
    _pendingFile = file;
    notifyListeners();
  }

  void clearFile() {
    _pendingFile = null;
    notifyListeners();
  }

  void clearAudio() {
    _pendingAudio = null;
    notifyListeners();
  }

  void setRecordingPhase(AudioRecordingPhase? phase) {
    if (phase == _recordingPhase) return;
    _recordingPhase = phase;
    notifyListeners();
  }

  /// The recorder stopped: leave recording mode and stage [audio] (null when
  /// nothing was captured) as the pending clip.
  void finishRecording(PickedAudio? audio) {
    _recordingPhase = null;
    if (audio != null) _pendingAudio = audio;
    notifyListeners();
  }

  /// Back out of a recording: drop the phase and any staged clip.
  void discardRecording() {
    _recordingPhase = null;
    _pendingAudio = null;
    notifyListeners();
  }
}
