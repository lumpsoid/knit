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

/// One photo staged in the composer (§4.2): the picked [original] and, once
/// "Optimize size" has run on it, its smaller [optimized] copy — or
/// [alreadySmall] when there was nothing worth saving.
@immutable
class StagedImage {
  const StagedImage(this.original, {this.optimized, this.alreadySmall = false});

  final PickedImage original;
  final PickedImage? optimized;
  final bool alreadySmall;

  /// Whether "Optimize size" can work on this photo's format.
  bool get canOptimize => ImageOptimization.canOptimize(original.mime);

  /// The optimiser has run on it (with or without a smaller copy).
  bool get optimizeDone => optimized != null || alreadySmall;
}

/// The Collection composer's state (§4.2) — a [ChangeNotifier] the
/// [CollectionComposerController] owns and mutates, and the page listens to.
///
/// Holds what the user is composing but hasn't sent: picked images, a recorded
/// clip, or a picked file (in memory only — nothing is stored or attached to a
/// card until the composer is sent), the live recording phase, and which inline
/// panel is open. The composer's text stays in the page's text field.
class CollectionComposerState extends ChangeNotifier {
  List<StagedImage> _images = const [];
  PickedAudio? _pendingAudio;
  PickedFile? _pendingFile;
  AudioRecordingPhase? _recordingPhase;
  ComposerPanel _panel = ComposerPanel.none;
  bool _optimizeImages = false;
  PickedImage? _optimizing;

  /// The picked images, in pick order, shown as thumbnails above the input
  /// field. One send makes one image card holding them all. Clearing just
  /// drops the bytes — no attachment is written.
  List<StagedImage> get pendingImages => _images;

  bool get hasPendingImages => _images.isNotEmpty;

  /// A recorded clip — the audio twin of [pendingImages], shown as a chip.
  PickedAudio? get pendingAudio => _pendingAudio;

  /// A picked file — the file twin of [pendingImages], shown by its name.
  PickedFile? get pendingFile => _pendingFile;

  /// The live audio-capture sub-state: non-null while recording or paused. Null
  /// once stopped — the captured clip then lives in [pendingAudio].
  AudioRecordingPhase? get recordingPhase => _recordingPhase;

  /// Whether the user chose "Optimise size" for photos. It stays on for the
  /// next photos picked on this page.
  bool get optimizeImages => _optimizeImages;

  /// The optimiser is working on one of [pendingImages]; a send waits for it.
  bool get optimizingImage => _optimizing != null;

  /// Whether the optimiser is working on [image] right now.
  bool isOptimizing(StagedImage image) =>
      identical(image.original, _optimizing);

  /// Whether any of [pendingImages] is a format "Optimise size" can work on.
  bool get canOptimizePendingImages => _images.any((i) => i.canOptimize);

  /// The bytes of every staged photo as picked.
  int get pendingImagesSize =>
      _images.fold(0, (sum, i) => sum + i.original.bytes.length);

  /// The bytes the send would store with "Optimise size" on, once every photo
  /// it can work on has been optimised; null until then.
  int? get optimizedImagesSize {
    if (_images.any((i) => i.canOptimize && !i.optimizeDone)) return null;
    return _images.fold<int>(
      0,
      (sum, i) => sum + (i.optimized ?? i.original).bytes.length,
    );
  }

  /// Optimising found nothing to save on any staged photo, so the originals
  /// are sent.
  bool get imagesAlreadySmall {
    final optimizable = _images.where((i) => i.canOptimize);
    return optimizable.isNotEmpty && optimizable.every((i) => i.alreadySmall);
  }

  /// The next photo the optimiser has to run on; null when none (or it is
  /// busy, or "Optimise size" is off).
  StagedImage? get nextToOptimize {
    if (!_optimizeImages || _optimizing != null) return null;
    for (final image in _images) {
      if (image.canOptimize && !image.optimizeDone) return image;
    }
    return null;
  }

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
      !optimizingImage &&
      (text.trim().isNotEmpty ||
          _images.isNotEmpty ||
          _pendingAudio != null ||
          _pendingFile != null);

  /// Build the send for [text] and drop what it carries, closing any panel.
  /// One kind of attachment rides per send — the images win, then a file, then
  /// a clip; whatever else is staged stays for the next send. Call only when
  /// [canSend] holds. Optimised photos go in place of their originals.
  ComposerSubmitted takeSubmission(String text) {
    final images = [
      for (final i in _images)
        (_optimizeImages ? i.optimized : null) ?? i.original,
    ];
    final file = images.isEmpty ? _pendingFile : null;
    final audio = images.isEmpty && file == null ? _pendingAudio : null;
    if (images.isNotEmpty) _dropImages();
    if (file != null) _pendingFile = null;
    if (audio != null) _pendingAudio = null;
    _panel = ComposerPanel.none;
    notifyListeners();
    return ComposerSubmitted(text, images: images, file: file, audio: audio);
  }

  void showPanel(ComposerPanel panel) {
    if (panel == _panel) return;
    _panel = panel;
    notifyListeners();
  }

  /// Add [images] after the ones already staged.
  void stageImages(List<PickedImage> images) {
    if (images.isEmpty) return;
    _images = [..._images, for (final i in images) StagedImage(i)];
    notifyListeners();
  }

  /// Drop the staged photo [image]; one being optimised stops there.
  void removeImage(StagedImage image) {
    if (isOptimizing(image)) _optimizing = null;
    _images = [
      for (final i in _images)
        if (!identical(i, image)) i,
    ];
    notifyListeners();
  }

  void clearImages() {
    _dropImages();
    notifyListeners();
  }

  /// Turning it off mid-run cancels the run: its result is dropped and a send
  /// goes through with the originals.
  void setOptimizeImages(bool optimize) {
    if (optimize == _optimizeImages) return;
    _optimizeImages = optimize;
    if (!optimize) _optimizing = null;
    notifyListeners();
  }

  void startOptimizing(StagedImage image) {
    _optimizing = image.original;
    notifyListeners();
  }

  /// The optimiser finished on [source]: keep the smaller [optimized] copy, or
  /// note that there was nothing to gain (null). Ignored when the run was
  /// cancelled or [source] is no longer staged.
  void finishOptimizing(PickedImage source, PickedImage? optimized) {
    if (!identical(source, _optimizing)) return;
    _optimizing = null;
    _images = [
      for (final i in _images)
        identical(i.original, source)
            ? StagedImage(
                source,
                optimized: optimized,
                alreadySmall: optimized == null,
              )
            : i,
    ];
    notifyListeners();
  }

  void _dropImages() {
    _images = const [];
    _optimizing = null;
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
