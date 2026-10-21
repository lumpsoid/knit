import 'dart:async';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:knit/core/attachments/attachments.dart';
import 'package:knit/features/collection/presentation/collection_action.dart';
import 'package:knit/features/collection/presentation/collection_composer_controller.dart';
import 'package:knit/features/collection/presentation/collection_composer_state.dart';
import 'package:knit/features/collection/presentation/collection_ui_effect.dart';
import 'package:logging/logging.dart';

class _FakeImagePicker implements ImagePickerPort {
  PickedImage? next;

  /// What a gallery pick returns; defaults to [next] alone.
  List<PickedImage>? nextMany;
  ImagePickerSource? lastSource;
  Completer<PickedImage?>? gate;

  @override
  Future<PickedImage?> pickImage({
    ImagePickerSource source = ImagePickerSource.gallery,
  }) async {
    lastSource = source;
    final gate = this.gate;
    if (gate != null) return gate.future;
    return next;
  }

  @override
  Future<List<PickedImage>> pickImages() async {
    lastSource = ImagePickerSource.gallery;
    final gate = this.gate;
    if (gate != null) return [?await gate.future];
    return nextMany ?? [?next];
  }
}

class _FakeOptimizer implements ImageOptimizerPort {
  PickedImage? next;
  Object? error;
  Completer<PickedImage?>? gate;
  final seen = <PickedImage>[];

  @override
  Future<PickedImage?> optimize(PickedImage image) async {
    seen.add(image);
    final error = this.error;
    if (error != null) throw error;
    final gate = this.gate;
    if (gate != null) return gate.future;
    return next;
  }
}

class _FakeFilePicker implements FilePickerPort {
  PickedFile? next;

  @override
  Future<PickedFile?> pickFile() async => next;
}

class _FakeRecorder implements AudioRecorderPort {
  bool grant = true;
  Object? startError;
  PickedAudio? clip;
  final calls = <String>[];

  @override
  Future<bool> start() async {
    calls.add('start');
    final error = startError;
    if (error != null) throw error;
    return grant;
  }

  @override
  Future<void> pause() async => calls.add('pause');
  @override
  Future<void> resume() async => calls.add('resume');
  @override
  Future<PickedAudio?> stop() async {
    calls.add('stop');
    return clip;
  }

  @override
  Future<void> cancel() async => calls.add('cancel');
}

void main() {
  final image = PickedImage(
    bytes: Uint8List.fromList([1, 2, 3]),
    mime: 'image/png',
  );
  final audio = PickedAudio(
    bytes: Uint8List.fromList([4, 5, 6]),
    mime: 'audio/mp4',
  );
  final file = PickedFile(
    bytes: Uint8List.fromList([7, 8, 9]),
    mime: 'application/pdf',
    name: 'report.pdf',
  );

  final smaller = PickedImage(
    bytes: Uint8List.fromList([1]),
    mime: 'image/jpeg',
  );

  late _FakeImagePicker imagePicker;
  late _FakeOptimizer optimizer;
  late _FakeFilePicker filePicker;
  late _FakeRecorder recorder;
  late List<ComposerSubmitted> sent;
  late List<CollectionMessage> messages;
  late CollectionComposerController composer;
  var disposed = false;

  setUp(() {
    imagePicker = _FakeImagePicker();
    optimizer = _FakeOptimizer();
    filePicker = _FakeFilePicker();
    recorder = _FakeRecorder();
    sent = [];
    messages = [];
    disposed = false;
    composer = CollectionComposerController(
      imagePicker: imagePicker,
      imageOptimizer: optimizer,
      audioRecorder: recorder,
      filePicker: filePicker,
      onSend: sent.add,
      onMessage: messages.add,
      logger: Logger('test.composer'),
    );
  });

  tearDown(() {
    if (!disposed) composer.dispose();
  });

  CollectionComposerState state() => composer.state;

  /// Stage a recorded clip by running a full record → stop round.
  Future<void> stageClip() async {
    recorder.clip = audio;
    await composer.startRecording();
    await composer.stopRecording();
  }

  group('send', () {
    test('plain text is sent and reported as sent', () {
      expect(composer.submit('hi'), isTrue);
      expect(sent.single.text, 'hi');
      expect(sent.single.images, isEmpty);
    });

    test('blank text with nothing staged sends nothing', () {
      expect(composer.submit('   '), isFalse);
      expect(sent, isEmpty);
    });

    test('a staged image goes with an empty caption and is dropped', () async {
      imagePicker.next = image;
      await composer.pickImage(ImagePickerSource.gallery);
      expect(composer.submit(''), isTrue);
      expect(sent.single.images.single, same(image));
      expect(state().pendingImages, isEmpty);
    });

    test('one attachment per send: image, then file, then clip', () async {
      imagePicker.next = image;
      filePicker.next = file;
      await composer.pickImage(ImagePickerSource.gallery);
      await composer.pickFile();
      await stageClip();

      composer.submit('1');
      composer.submit('2');
      composer.submit('3');

      expect(sent[0].images.single, same(image));
      expect(sent[0].file, isNull);
      expect(sent[0].audio, isNull);
      expect(sent[1].file, same(file));
      expect(sent[1].audio, isNull);
      expect(sent[2].audio, same(audio));
      expect(state().pendingAudio, isNull);
    });

    test('send is inert while a recording is in flight', () async {
      await composer.startRecording();
      expect(composer.submit('hi'), isFalse);
      expect(sent, isEmpty);
      expect(state().recordingPhase, AudioRecordingPhase.recording);
    });

    test('a send closes an open panel', () {
      composer.showPhotoSources();
      composer.submit('hi');
      expect(state().panel, ComposerPanel.none);
    });
  });

  group('photo', () {
    test('picking hides the options and stages the image', () async {
      composer.showPhotoSources();
      imagePicker.next = image;
      await composer.pickImage(ImagePickerSource.camera);
      expect(imagePicker.lastSource, ImagePickerSource.camera);
      expect(state().showPhotoSources, isFalse);
      expect(state().pendingImages.single.original, same(image));
    });

    test('a cancelled pick keeps the staged image', () async {
      imagePicker.next = image;
      await composer.pickImage(ImagePickerSource.gallery);
      imagePicker.next = null;
      await composer.pickImage(ImagePickerSource.gallery);
      expect(state().pendingImages.single.original, same(image));
    });

    test('clearing drops the staged image', () async {
      imagePicker.next = image;
      await composer.pickImage(ImagePickerSource.gallery);
      composer.clearImages();
      expect(state().pendingImages, isEmpty);
    });

    test('a gallery pick stages every photo, in pick order', () async {
      final second = PickedImage(
        bytes: Uint8List.fromList([7]),
        mime: 'image/png',
      );
      imagePicker.nextMany = [image, second];
      await composer.pickImage(ImagePickerSource.gallery);
      expect(
        [for (final i in state().pendingImages) i.original],
        [image, second],
      );
    });

    test(
      'more picks join the staged photos; one send carries them all',
      () async {
        final shot = PickedImage(
          bytes: Uint8List.fromList([7]),
          mime: 'image/png',
        );
        imagePicker.next = image;
        await composer.pickImage(ImagePickerSource.gallery);
        imagePicker.next = shot;
        await composer.pickImage(ImagePickerSource.camera);
        expect(composer.submit('two'), isTrue);
        expect(sent.single.images, [image, shot]);
        expect(sent.single.text, 'two');
        expect(state().pendingImages, isEmpty);
      },
    );

    test('removing one staged photo keeps the others', () async {
      final second = PickedImage(
        bytes: Uint8List.fromList([7]),
        mime: 'image/png',
      );
      imagePicker.nextMany = [image, second];
      await composer.pickImage(ImagePickerSource.gallery);
      composer.removeImage(state().pendingImages.first);
      expect(state().pendingImages.single.original, same(second));
    });

    test('photo options and the audio bar are exclusive', () {
      composer.showPhotoSources();
      composer.showAudioBar();
      expect(state().showPhotoSources, isFalse);
      expect(state().showAudioBar, isTrue);
      composer.showPhotoSources();
      expect(state().showAudioBar, isFalse);
    });

    test('a pick that lands after the page left is dropped', () async {
      final gate = Completer<PickedImage?>();
      imagePicker.gate = gate;
      final pick = composer.pickImage(ImagePickerSource.gallery);
      composer.dispose();
      disposed = true;
      gate.complete(image);
      await expectLater(pick, completes);
    });
  });

  group('optimize size', () {
    Future<void> stage(PickedImage picked) async {
      imagePicker.next = picked;
      await composer.pickImage(ImagePickerSource.gallery);
    }

    test('off by default: the original is sent untouched', () async {
      optimizer.next = smaller;
      await stage(image);
      expect(optimizer.seen, isEmpty);
      composer.submit('');
      expect(sent.single.images.single, same(image));
    });

    test(
      'turning it on optimizes the staged photo and sends the copy',
      () async {
        optimizer.next = smaller;
        await stage(image);
        await composer.setOptimizeImages(true);
        expect(state().pendingImages.single.optimized, same(smaller));
        composer.submit('caption');
        expect(sent.single.images.single, same(smaller));
        expect(sent.single.text, 'caption');
      },
    );

    test('turning it back off sends the original', () async {
      optimizer.next = smaller;
      await stage(image);
      await composer.setOptimizeImages(true);
      await composer.setOptimizeImages(false);
      composer.submit('');
      expect(sent.single.images.single, same(image));
    });

    test('the choice carries over to the next photo', () async {
      optimizer.next = smaller;
      await stage(image);
      await composer.setOptimizeImages(true);
      composer.submit('');
      final next = PickedImage(
        bytes: Uint8List.fromList([9, 9]),
        mime: 'image/jpeg',
      );
      await stage(next);
      expect(optimizer.seen, [image, next]);
      expect(state().optimizeImages, isTrue);
    });

    test('a send waits while optimizing', () async {
      final gate = Completer<PickedImage?>();
      optimizer.gate = gate;
      await stage(image);
      final running = composer.setOptimizeImages(true);
      expect(state().optimizingImage, isTrue);
      expect(composer.submit('hi'), isFalse);
      gate.complete(smaller);
      await running;
      expect(composer.submit('hi'), isTrue);
      expect(sent.single.images.single, same(smaller));
    });

    test('turning it off mid-run cancels: the original goes at once', () async {
      final gate = Completer<PickedImage?>();
      optimizer.gate = gate;
      await stage(image);
      final running = composer.setOptimizeImages(true);
      await composer.setOptimizeImages(false);
      expect(state().optimizingImage, isFalse);
      expect(composer.submit(''), isTrue);
      expect(sent.single.images.single, same(image));
      gate.complete(smaller);
      await running;
      expect(state().pendingImages, isEmpty);
    });

    test('nothing to gain keeps the original and says so', () async {
      optimizer.next = null;
      await stage(image);
      await composer.setOptimizeImages(true);
      expect(state().imagesAlreadySmall, isTrue);
      composer.submit('');
      expect(sent.single.images.single, same(image));
    });

    test('an optimizer error keeps the original', () async {
      optimizer.error = StateError('boom');
      await stage(image);
      await composer.setOptimizeImages(true);
      expect(state().optimizingImage, isFalse);
      composer.submit('');
      expect(sent.single.images.single, same(image));
    });

    test('a format it cannot read is left alone', () async {
      final gif = PickedImage(
        bytes: Uint8List.fromList([1]),
        mime: 'image/gif',
      );
      await stage(gif);
      expect(state().canOptimizePendingImages, isFalse);
      await composer.setOptimizeImages(true);
      expect(optimizer.seen, isEmpty);
      composer.submit('');
      expect(sent.single.images.single, same(gif));
    });

    test('it runs over every staged photo, one at a time', () async {
      final second = PickedImage(
        bytes: Uint8List.fromList([5, 5, 5]),
        mime: 'image/jpeg',
      );
      imagePicker.nextMany = [image, second];
      await composer.pickImage(ImagePickerSource.gallery);
      optimizer.next = smaller;
      await composer.setOptimizeImages(true);
      expect(optimizer.seen, [image, second]);
      expect(state().optimizedImagesSize, 2);
      composer.submit('');
      expect(sent.single.images, [smaller, smaller]);
    });

    test('a result for a photo that was replaced is dropped', () async {
      final gate = Completer<PickedImage?>();
      optimizer.gate = gate;
      await stage(image);
      final running = composer.setOptimizeImages(true);
      composer.clearImages();
      gate.complete(smaller);
      await running;
      expect(state().pendingImages, isEmpty);
      expect(state().optimizingImage, isFalse);
    });
  });

  group('file', () {
    test('a picked file is staged; a cancelled pick changes nothing', () async {
      await composer.pickFile();
      expect(state().pendingFile, isNull);
      filePicker.next = file;
      await composer.pickFile();
      expect(state().pendingFile, same(file));
      composer.clearFile();
      expect(state().pendingFile, isNull);
    });
  });

  group('audio recording', () {
    test('a confirmed start enters the recording phase', () async {
      composer.showAudioBar();
      await composer.startRecording();
      expect(recorder.calls, ['start']);
      expect(state().recordingPhase, AudioRecordingPhase.recording);
      expect(state().isRecordingAudio, isTrue);
    });

    test('a denied microphone says why and stays idle', () async {
      recorder.grant = false;
      await composer.startRecording();
      expect(state().recordingPhase, isNull);
      expect(messages, [CollectionMessage.micPermissionDenied]);
    });

    test('a recorder error says save failed and stays idle', () async {
      recorder.startError = StateError('boom');
      await composer.startRecording();
      expect(state().recordingPhase, isNull);
      expect(messages, [CollectionMessage.saveFailed]);
    });

    test('pause and resume flip the phase and tell the recorder', () async {
      await composer.startRecording();
      await composer.pauseRecording();
      expect(state().recordingPhase, AudioRecordingPhase.paused);
      await composer.resumeRecording();
      expect(state().recordingPhase, AudioRecordingPhase.recording);
      expect(recorder.calls, ['start', 'pause', 'resume']);
    });

    test('stop hides the bar and stages the captured clip', () async {
      composer.showAudioBar();
      await stageClip();
      expect(state().showAudioBar, isFalse);
      expect(state().recordingPhase, isNull);
      expect(state().pendingAudio, same(audio));
    });

    test('an empty capture just leaves recording mode', () async {
      await composer.startRecording();
      await composer.stopRecording();
      expect(state().recordingPhase, isNull);
      expect(state().pendingAudio, isNull);
    });

    test('closing the bar mid-recording discards it', () async {
      await stageClip();
      composer.showAudioBar();
      await composer.startRecording();
      await composer.closeAudioBar();
      expect(state().showAudioBar, isFalse);
      expect(state().recordingPhase, isNull);
      expect(state().pendingAudio, isNull);
      expect(recorder.calls.last, 'cancel');
    });

    test('closing the idle bar leaves the recorder alone', () async {
      composer.showAudioBar();
      await composer.closeAudioBar();
      expect(state().showAudioBar, isFalse);
      expect(recorder.calls, isEmpty);
    });

    test('clearing drops the staged clip', () async {
      await stageClip();
      composer.clearAudio();
      expect(state().pendingAudio, isNull);
    });

    test('leaving the page cancels an in-flight recording', () async {
      await composer.startRecording();
      composer.dispose();
      disposed = true;
      await Future<void>.delayed(Duration.zero);
      expect(recorder.calls, ['start', 'cancel']);
    });

    test('leaving the page with no recording leaves the recorder alone', () {
      composer.dispose();
      disposed = true;
      expect(recorder.calls, isEmpty);
    });
  });
}
