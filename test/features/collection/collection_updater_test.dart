import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:knit/core/attachments/domain/image_picker_port.dart';
import 'package:knit/core/attachments/domain/picked_audio.dart';
import 'package:knit/core/attachments/domain/picked_file.dart';
import 'package:knit/core/attachments/domain/picked_image.dart';
import 'package:knit/features/collection/domain/collection_models.dart';
import 'package:knit/features/collection/presentation/collection_action.dart';
import 'package:knit/features/collection/presentation/collection_effect.dart';
import 'package:knit/features/collection/presentation/collection_state.dart';
import 'package:knit/features/collection/presentation/collection_updater.dart';
import 'package:knit/features/connections/domain/connections_models.dart';

void main() {
  const updater = CollectionUpdater();

  final image = PickedImage(
    bytes: Uint8List.fromList([1, 2, 3]),
    mime: 'image/png',
  );

  final audio = PickedAudio(
    bytes: Uint8List.fromList([4, 5, 6]),
    mime: 'audio/mp4',
  );

  final pickedFile = PickedFile(
    bytes: Uint8List.fromList([7, 8, 9]),
    mime: 'application/pdf',
    name: 'report.pdf',
  );

  FeedCard card(String id, String position, {CardKind kind = CardKind.text}) =>
      FeedCard(id: id, kind: kind, position: position, text: id);

  CollectionState ready(List<FeedCard> cards) => CollectionState(
    status: CollectionStatus.ready,
    collectionId: 'col',
    title: 'Notes',
    cards: cards,
  );

  test('ViewAttached loads the given collection', () {
    final (next, effects) = updater.update(
      const CollectionState(),
      const ViewAttached('col-1'),
    );
    expect(next.status, CollectionStatus.loading);
    expect(next.collectionId, 'col-1');
    expect((effects!.single as LoadCollectionEffect).collectionId, 'col-1');
  });

  test('ReloadRequested is a no-op before a collection is set', () {
    final (_, effects) = updater.update(
      const CollectionState(),
      const ReloadRequested(),
    );
    expect(effects, isNull);
  });

  test('CollectionLoaded becomes ready with the feed', () {
    final data = CollectionData(
      collectionId: 'col',
      title: 'Notes',
      coverAttachmentId: null,
      cards: [card('c1', 'a0')],
    );
    final (next, effects) = updater.update(
      const CollectionState(),
      CollectionLoaded(data),
    );
    expect(next.status, CollectionStatus.ready);
    expect(next.cards.single.id, 'c1');
    expect(effects, isNull);
  });

  group('image thumbnails', () {
    CollectionData dataWith(List<FeedCard> cards) => CollectionData(
      collectionId: 'col',
      title: 'Notes',
      coverAttachmentId: null,
      cards: cards,
    );

    FeedCard imageCard(String id, String position, String? attachmentId) =>
        FeedCard(
          id: id,
          kind: CardKind.image,
          position: position,
          attachmentId: attachmentId,
        );

    test('CollectionLoaded loads bytes for each uncached image card', () {
      final data = dataWith([
        card('c1', 'a0'),
        imageCard('c2', 'a1', 'att-1'),
        imageCard('c3', 'a2', 'att-2'),
      ]);
      final (_, effects) = updater.update(
        const CollectionState(),
        CollectionLoaded(data),
      );
      final ids = effects!
          .whereType<LoadImageBytesEffect>()
          .map((e) => e.attachmentId)
          .toList();
      expect(ids, ['att-1', 'att-2']);
    });

    test('an image card without an attachment id loads nothing', () {
      final data = dataWith([imageCard('c1', 'a0', null)]);
      final (_, effects) = updater.update(
        const CollectionState(),
        CollectionLoaded(data),
      );
      expect(effects, isNull);
    });

    test('already-cached bytes are not reloaded, and the cache survives', () {
      final bytes = Uint8List.fromList([1, 2, 3]);
      final state = const CollectionState().copyWith(
        imageBytes: {'att-1': bytes},
      );
      final data = dataWith([
        imageCard('c1', 'a0', 'att-1'),
        imageCard('c2', 'a1', 'att-2'),
      ]);
      final (next, effects) = updater.update(state, CollectionLoaded(data));
      final ids = effects!
          .whereType<LoadImageBytesEffect>()
          .map((e) => e.attachmentId)
          .toList();
      expect(ids, ['att-2'], reason: 'att-1 already cached');
      expect(next.imageBytes['att-1'], same(bytes), reason: 'cache preserved');
    });

    test('ImageBytesLoaded caches the decoded bytes', () {
      final bytes = Uint8List.fromList([9, 9]);
      final (next, effects) = updater.update(
        ready(const []),
        ImageBytesLoaded('att-1', bytes),
      );
      expect(next.imageBytes['att-1'], same(bytes));
      expect(effects, isNull);
    });

    test('a missing image (null bytes) is not cached', () {
      final (next, effects) = updater.update(
        ready(const []),
        const ImageBytesLoaded('att-1', null),
      );
      expect(next.imageBytes.containsKey('att-1'), isFalse);
      expect(effects, isNull);
    });
  });

  group('composer / append positions', () {
    test('first card on an empty feed gets the first key', () {
      final (_, effects) = updater.update(
        ready(const []),
        const ComposerSubmitted('hi'),
      );
      final effect = effects!.single as AddCardEffect;
      expect(effect.kind, CardKind.text);
      expect(effect.position, 'a0');
      expect(effect.text, 'hi');
    });

    test('subsequent card appends after the last position', () {
      final (_, effects) = updater.update(
        ready([card('c1', 'a0')]),
        const ComposerSubmitted('  next  '),
      );
      final effect = effects!.single as AddCardEffect;
      expect(effect.position.compareTo('a0') > 0, isTrue);
      expect(effect.text, 'next', reason: 'trimmed');
    });

    test('blank composer text produces no effect', () {
      final (_, effects) = updater.update(
        ready(const []),
        const ComposerSubmitted('   '),
      );
      expect(effects, isNull);
    });

    test('link block appends a link-kind card', () {
      final (_, effects) = updater.update(
        ready(const []),
        const LinkCardSubmitted('https://x.y'),
      );
      final effect = effects!.single as AddCardEffect;
      expect(effect.kind, CardKind.link);
      expect(effect.text, 'https://x.y');
    });

    test('photo block opens the picker on the chosen source', () {
      final (next, effects) = updater.update(
        ready(const []),
        const PickImageRequested(ImagePickerSource.camera),
      );
      final effect = effects!.single as PickImageEffect;
      expect(effect.source, ImagePickerSource.camera);
      expect(next.pendingImage, isNull, reason: 'nothing staged until picked');
    });

    test('a picked image is staged as the composer preview', () {
      final (next, effects) = updater.update(
        ready(const []),
        ImagePicked(image),
      );
      expect(next.pendingImage, same(image));
      expect(effects, isNull);
    });

    test('a cancelled pick leaves the preview untouched', () {
      final (next, effects) = updater.update(
        ready(const []).copyWith(pendingImage: image),
        const ImagePicked(null),
      );
      expect(next.pendingImage, same(image));
      expect(effects, isNull);
    });

    test('clearing the preview drops the staged image', () {
      final (next, effects) = updater.update(
        ready(const []).copyWith(pendingImage: image),
        const PendingImageCleared(),
      );
      expect(next.pendingImage, isNull);
      expect(effects, isNull);
    });

    test(
      'sending with a staged image emits a photo card and clears the preview',
      () {
        final (next, effects) = updater.update(
          ready([card('c1', 'a0')]).copyWith(pendingImage: image),
          const ComposerSubmitted('  a caption  '),
        );
        final effect = effects!.single as AddPhotoCardEffect;
        expect(effect.collectionId, 'col');
        expect(effect.position.compareTo('a0') > 0, isTrue);
        expect(effect.caption, 'a caption', reason: 'trimmed');
        expect(effect.image, same(image));
        expect(next.pendingImage, isNull, reason: 'cleared optimistically');
      },
    );

    test('sending a staged image with blank text carries a null caption', () {
      final (_, effects) = updater.update(
        ready(const []).copyWith(pendingImage: image),
        const ComposerSubmitted('   '),
      );
      final effect = effects!.single as AddPhotoCardEffect;
      expect(effect.caption, isNull);
      expect(effect.position, 'a0');
    });
  });

  group('audio recording', () {
    test('start request opens the recorder but stages no phase yet', () {
      final (next, effects) = updater.update(
        ready(const []),
        const AudioRecordingRequested(),
      );
      expect(effects!.single, isA<StartAudioRecordingEffect>());
      expect(next.recordingPhase, isNull, reason: 'wait for the recorder');
    });

    test('a confirmed start enters the recording phase', () {
      final (next, effects) = updater.update(
        ready(const []),
        const AudioRecordingStarted(),
      );
      expect(next.recordingPhase, AudioRecordingPhase.recording);
      expect(effects, isNull);
    });

    test('a failed start leaves recording mode', () {
      final state = ready(
        const [],
      ).copyWith(recordingPhase: AudioRecordingPhase.recording);
      final (next, effects) = updater.update(
        state,
        const AudioRecordingStartFailed(),
      );
      expect(next.recordingPhase, isNull);
      expect(effects, isNull);
    });

    test('pause flips the phase optimistically and tells the recorder', () {
      final state = ready(
        const [],
      ).copyWith(recordingPhase: AudioRecordingPhase.recording);
      final (next, effects) = updater.update(
        state,
        const AudioRecordingPauseRequested(),
      );
      expect(next.recordingPhase, AudioRecordingPhase.paused);
      expect(effects!.single, isA<PauseAudioRecordingEffect>());
    });

    test('resume flips back to recording and tells the recorder', () {
      final state = ready(
        const [],
      ).copyWith(recordingPhase: AudioRecordingPhase.paused);
      final (next, effects) = updater.update(
        state,
        const AudioRecordingResumeRequested(),
      );
      expect(next.recordingPhase, AudioRecordingPhase.recording);
      expect(effects!.single, isA<ResumeAudioRecordingEffect>());
    });

    test('stop requests the clip without yet leaving the phase', () {
      final state = ready(
        const [],
      ).copyWith(recordingPhase: AudioRecordingPhase.recording);
      final (next, effects) = updater.update(
        state,
        const AudioRecordingStopRequested(),
      );
      expect(effects!.single, isA<StopAudioRecordingEffect>());
      expect(next.recordingPhase, AudioRecordingPhase.recording);
    });

    test('a captured clip is staged as the preview and clears the phase', () {
      final state = ready(
        const [],
      ).copyWith(recordingPhase: AudioRecordingPhase.recording);
      final (next, effects) = updater.update(state, AudioRecorded(audio));
      expect(next.pendingAudio, same(audio));
      expect(next.recordingPhase, isNull);
      expect(effects, isNull);
    });

    test('an empty capture just leaves recording mode', () {
      final state = ready(
        const [],
      ).copyWith(recordingPhase: AudioRecordingPhase.recording);
      final (next, effects) = updater.update(
        state,
        const AudioRecorded(null),
      );
      expect(next.pendingAudio, isNull);
      expect(next.recordingPhase, isNull);
      expect(effects, isNull);
    });

    test('cancel drops everything and discards the recording', () {
      final state = ready(const []).copyWith(
        recordingPhase: AudioRecordingPhase.recording,
      );
      final (next, effects) = updater.update(
        state,
        const AudioRecordingCancelled(),
      );
      expect(next.recordingPhase, isNull);
      expect(next.pendingAudio, isNull);
      expect(effects!.single, isA<CancelAudioRecordingEffect>());
    });

    test('clearing the pending clip drops it with no effect', () {
      final state = ready(const []).copyWith(pendingAudio: audio);
      final (next, effects) = updater.update(
        state,
        const PendingAudioCleared(),
      );
      expect(next.pendingAudio, isNull);
      expect(effects, isNull);
    });

    test('sending a staged clip emits an audio card and clears it', () {
      final state = ready([card('c1', 'a0')]).copyWith(pendingAudio: audio);
      final (next, effects) = updater.update(
        state,
        const ComposerSubmitted('  a note  '),
      );
      final effect = effects!.single as AddAudioCardEffect;
      expect(effect.collectionId, 'col');
      expect(effect.position.compareTo('a0') > 0, isTrue);
      expect(effect.caption, 'a note', reason: 'trimmed');
      expect(effect.audio, same(audio));
      expect(next.pendingAudio, isNull, reason: 'cleared optimistically');
    });

    test('sending a staged clip with blank text carries a null caption', () {
      final state = ready(const []).copyWith(pendingAudio: audio);
      final (_, effects) = updater.update(
        state,
        const ComposerSubmitted('   '),
      );
      final effect = effects!.single as AddAudioCardEffect;
      expect(effect.caption, isNull);
      expect(effect.position, 'a0');
    });

    test('a pending image wins over a pending clip on send', () {
      final state = ready(const [])
          .copyWith(pendingImage: image, pendingAudio: audio);
      final (_, effects) = updater.update(
        state,
        const ComposerSubmitted('hi'),
      );
      expect(effects!.single, isA<AddPhotoCardEffect>());
    });

    test('send is inert while a recording is in flight', () {
      final state = ready(
        const [],
      ).copyWith(recordingPhase: AudioRecordingPhase.recording);
      final (next, effects) = updater.update(
        state,
        const ComposerSubmitted('hi'),
      );
      expect(effects, isNull);
      expect(next.recordingPhase, AudioRecordingPhase.recording);
    });

    test('leaving the page cancels an in-flight recording', () {
      final state = ready(
        const [],
      ).copyWith(recordingPhase: AudioRecordingPhase.recording);
      final (next, effects) = updater.update(
        state,
        const DeactivateFeature(),
      );
      expect(next.recordingPhase, isNull);
      expect(effects!.single, isA<CancelAudioRecordingEffect>());
    });

    test('leaving the page with no recording emits no cancel', () {
      final (next, effects) = updater.update(
        ready(const []),
        const DeactivateFeature(),
      );
      expect(next.recordingPhase, isNull);
      expect(effects, isNull);
    });
  });

  group('file attachment', () {
    test('PickFileRequested emits the pick effect, stages nothing yet', () {
      final (next, effects) = updater.update(
        ready(const []),
        const PickFileRequested(),
      );
      expect(effects!.single, isA<PickFileEffect>());
      expect(next.pendingFile, isNull, reason: 'nothing staged until picked');
    });

    test('a cancelled pick leaves state unchanged', () {
      final (next, effects) = updater.update(
        ready(const []),
        const FilePicked(null),
      );
      expect(next.pendingFile, isNull);
      expect(effects, isNull);
    });

    test('a picked file is staged as the pending preview', () {
      final (next, effects) = updater.update(
        ready(const []),
        FilePicked(pickedFile),
      );
      expect(next.pendingFile, same(pickedFile));
      expect(effects, isNull);
    });

    test('clearing the pending file drops it with no effect', () {
      final state = ready(const []).copyWith(pendingFile: pickedFile);
      final (next, effects) = updater.update(
        state,
        const PendingFileCleared(),
      );
      expect(next.pendingFile, isNull);
      expect(effects, isNull);
    });

    test('sending a staged file emits a file card and clears it', () {
      final state = ready([card('c1', 'a0')]).copyWith(pendingFile: pickedFile);
      final (next, effects) = updater.update(
        state,
        const ComposerSubmitted('  a caption  '),
      );
      final effect = effects!.single as AddFileCardEffect;
      expect(effect.collectionId, 'col');
      expect(effect.position.compareTo('a0') > 0, isTrue);
      expect(effect.caption, 'a caption', reason: 'trimmed');
      expect(effect.file, same(pickedFile));
      expect(next.pendingFile, isNull, reason: 'cleared optimistically');
    });

    test('sending a staged file with blank text carries a null caption', () {
      final state = ready(const []).copyWith(pendingFile: pickedFile);
      final (_, effects) = updater.update(
        state,
        const ComposerSubmitted('   '),
      );
      final effect = effects!.single as AddFileCardEffect;
      expect(effect.caption, isNull);
      expect(effect.position, 'a0');
    });

    test('a pending image wins over a pending file on send', () {
      final state = ready(const [])
          .copyWith(pendingImage: image, pendingFile: pickedFile);
      final (_, effects) = updater.update(
        state,
        const ComposerSubmitted('hi'),
      );
      expect(effects!.single, isA<AddPhotoCardEffect>());
    });

    test('leaving the page drops a staged file', () {
      final state = ready(const []).copyWith(pendingFile: pickedFile);
      final (next, _) = updater.update(state, const DeactivateFeature());
      expect(next.pendingFile, isNull);
    });
  });

  group('delete / link', () {
    test('delete emits DeleteCardEffect', () {
      final (_, effects) = updater.update(
        ready([card('c1', 'a0')]),
        const CardDeleteRequested('c1'),
      );
      expect((effects!.single as DeleteCardEffect).cardId, 'c1');
    });

    test('link to a collection emits LinkEffect with the collection kind', () {
      final (_, effects) = updater.update(
        ready([card('c1', 'a0')]),
        const LinkRequested(
          cardId: 'c1',
          targetKind: ConnectedEntityKind.collection,
          targetId: 'col-2',
        ),
      );
      final effect = effects!.single as LinkEffect;
      expect(
        (effect.cardId, effect.targetKind, effect.targetId),
        ('c1', ConnectedEntityKind.collection, 'col-2'),
      );
    });

    test('link to a card emits LinkEffect with the card kind', () {
      final (_, effects) = updater.update(
        ready([card('c1', 'a0')]),
        const LinkRequested(
          cardId: 'c1',
          targetKind: ConnectedEntityKind.card,
          targetId: 'c9',
        ),
      );
      final effect = effects!.single as LinkEffect;
      expect(
        (effect.cardId, effect.targetKind, effect.targetId),
        ('c1', ConnectedEntityKind.card, 'c9'),
      );
    });
  });

  group('share', () {
    // First 12 hex of the (dash-stripped) id are the UUIDv7 ms timestamp.
    const v7Id = '01890a5d-ac96-7000-8000-000000000000';

    FeedCard photo(String id, {String? caption}) => FeedCard(
      id: id,
      kind: CardKind.image,
      position: 'a0',
      text: caption,
      attachmentId: 'att-1',
    );

    test('a text card emits ShareCardEffect with its text, no attachment', () {
      final (_, effects) = updater.update(
        ready([card('c1', 'a0')]),
        const CardShareRequested('c1'),
      );
      final effect = effects!.single as ShareCardEffect;
      expect(effect.text, 'c1');
      expect(effect.attachmentId, isNull);
    });

    test('an image card shares the photo plus its caption, date-stamped', () {
      final (_, effects) = updater.update(
        ready([photo(v7Id, caption: 'a caption')]),
        const CardShareRequested(v7Id),
      );
      final effect = effects!.single as ShareCardEffect;
      expect(effect.text, 'a caption');
      expect(effect.attachmentId, 'att-1');
      expect(effect.imageBaseName, matches(r'^\d{4}-\d{2}-\d{2}-knit$'));
    });

    test('an image card with no caption shares the photo alone', () {
      final (_, effects) = updater.update(
        ready([photo(v7Id)]),
        const CardShareRequested(v7Id),
      );
      final effect = effects!.single as ShareCardEffect;
      expect(effect.text, isNull);
      expect(effect.attachmentId, 'att-1');
    });

    test('the photo file-name stem falls back to "knit" for a non-v7 id', () {
      final (_, effects) = updater.update(
        ready([photo('not-a-uuid')]),
        const CardShareRequested('not-a-uuid'),
      );
      expect((effects!.single as ShareCardEffect).imageBaseName, 'knit');
    });

    test('an empty text card is a pure no-op', () {
      final empty = FeedCard(id: 'c1', kind: CardKind.text, position: 'a0');
      final (_, effects) = updater.update(
        ready([empty]),
        const CardShareRequested('c1'),
      );
      expect(effects, isNull);
    });

    test('an unknown card id is a pure no-op', () {
      final (_, effects) = updater.update(
        ready([card('c1', 'a0')]),
        const CardShareRequested('missing'),
      );
      expect(effects, isNull);
    });

    test('a file card shares its attachment under its stored name', () {
      final fileCard = FeedCard(
        id: 'f1',
        kind: CardKind.file,
        position: 'a0',
        attachmentId: 'att-9',
        fileName: 'report.pdf',
        fileSize: 1234,
      );
      final (_, effects) = updater.update(
        ready([fileCard]),
        const CardShareRequested('f1'),
      );
      final effect = effects!.single as ShareCardEffect;
      expect(effect.attachmentId, 'att-9');
      expect(effect.fileName, 'report.pdf');
    });
  });

  group('link finder (lazy levels)', () {
    const optCol = LinkOption(
      kind: ConnectedEntityKind.collection,
      id: 'col-2',
      label: 'Other',
    );
    const optCard = LinkOption(
      kind: ConnectedEntityKind.card,
      id: 'c9',
      label: 'a card',
    );

    test('opening the finder loads the collections level', () {
      final (_, effects) = updater.update(
        ready(const []),
        const LinkFinderOpened(),
      );
      expect(effects!.single, isA<LoadLinkCollectionsEffect>());
    });

    test('LinkCollectionsLoaded stores the first level', () {
      final (next, effects) = updater.update(
        ready(const []),
        const LinkCollectionsLoaded([optCol]),
      );
      expect(next.linkCollections, [optCol]);
      expect(effects, isNull);
    });

    test('drilling on a cache miss loads that collection\'s cards', () {
      final (_, effects) = updater.update(
        ready(const []),
        const LinkCollectionOpened('col-2'),
      );
      expect(
        (effects!.single as LoadCollectionCardsEffect).collectionId,
        'col-2',
      );
    });

    test('drilling on a cache hit is a pure no-op', () {
      final state = ready(const []).copyWith(
        linkCardsByCollection: const {
          'col-2': [optCard],
        },
      );
      final (next, effects) = updater.update(
        state,
        const LinkCollectionOpened('col-2'),
      );
      expect(effects, isNull);
      expect(next.linkCardsByCollection['col-2'], [optCard]);
    });

    test('LinkCardsLoaded caches under the collection id', () {
      final (next, effects) = updater.update(
        ready(const []),
        const LinkCardsLoaded('col-2', [optCard]),
      );
      expect(next.linkCardsByCollection['col-2'], [optCard]);
      expect(effects, isNull);
    });

    test('a feed reload drops the finder caches (re-read fresh on reopen)', () {
      final state = ready([card('c1', 'a0')]).copyWith(
        linkCollections: const [optCol],
        linkCardsByCollection: const {
          'col-2': [optCard],
        },
      );
      final data = CollectionData(
        collectionId: 'col',
        title: 'Notes',
        coverAttachmentId: null,
        cards: [card('c1', 'a0')],
      );
      final (next, _) = updater.update(state, CollectionLoaded(data));
      expect(next.linkCollections, isNull);
      expect(next.linkCardsByCollection, isEmpty);
    });
  });

  group('reorder mode', () {
    test('start / end toggles the mode flag', () {
      final (started, _) = updater.update(
        ready(const []),
        const StartReorder(),
      );
      expect(started.reordering, isTrue);
      final (ended, _) = updater.update(started, const EndReorder());
      expect(ended.reordering, isFalse);
    });

    test('moving a card to the end re-keys it after its new predecessor', () {
      final state = ready([
        card('c1', 'a0'),
        card('c2', 'a1'),
        card('c3', 'a2'),
      ]);
      // ReorderableListView reports newIndex as the pre-removal slot.
      final (next, effects) = updater.update(state, const CardMoved(0, 3));
      final effect = effects!.single as ReorderCardEffect;
      expect(effect.cardId, 'c1');
      // Order is now c2, c3, c1 — and stays sorted by position.
      expect(next.cards.map((c) => c.id), ['c2', 'c3', 'c1']);
      final positions = next.cards.map((c) => c.position).toList();
      final sorted = [...positions]..sort();
      expect(positions, sorted);
      expect(effect.position, next.cards.last.position);
    });

    test('moving a card to the front re-keys it before the new successor', () {
      final state = ready([
        card('c1', 'a0'),
        card('c2', 'a1'),
        card('c3', 'a2'),
      ]);
      final (next, effects) = updater.update(state, const CardMoved(2, 0));
      final effect = effects!.single as ReorderCardEffect;
      expect(effect.cardId, 'c3');
      expect(next.cards.map((c) => c.id), ['c3', 'c1', 'c2']);
      expect(next.cards.first.position.compareTo('a0') < 0, isTrue);
    });

    test('a no-op move produces no effect', () {
      final state = ready([card('c1', 'a0'), card('c2', 'a1')]);
      final (_, effects) = updater.update(state, const CardMoved(1, 1));
      expect(effects, isNull);
    });

    test('survives the post-write re-sync — a single move keeps the mode', () {
      final state = ready([
        card('c1', 'a0'),
        card('c2', 'a1'),
      ]).copyWith(reordering: true);
      final data = CollectionData(
        collectionId: 'col',
        title: 'Notes',
        coverAttachmentId: null,
        cards: [card('c2', 'a1'), card('c1', 'a2')],
      );
      final (next, _) = updater.update(state, CollectionLoaded(data));
      expect(next.reordering, isTrue);
    });

    test('drops the mode when the re-synced feed shrinks below 2 cards', () {
      final state = ready([
        card('c1', 'a0'),
        card('c2', 'a1'),
      ]).copyWith(reordering: true);
      final data = CollectionData(
        collectionId: 'col',
        title: 'Notes',
        coverAttachmentId: null,
        cards: [card('c1', 'a0')],
      );
      final (next, _) = updater.update(state, CollectionLoaded(data));
      expect(next.reordering, isFalse);
    });
  });

  test('title submit updates header optimistically and emits the write', () {
    final (next, effects) = updater.update(
      ready(const []),
      const TitleSubmitted('  Renamed  '),
    );
    expect(next.title, 'Renamed');
    final effect = effects!.single as EditTitleEffect;
    expect((effect.collectionId, effect.title), ('col', 'Renamed'));
  });
}
