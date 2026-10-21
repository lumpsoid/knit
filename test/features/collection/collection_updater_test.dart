import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:knit/core/attachments/domain/picked_audio.dart';
import 'package:knit/core/attachments/domain/picked_file.dart';
import 'package:knit/core/attachments/domain/picked_image.dart';
import 'package:knit/core/ordering/fractional_index.dart';
import 'package:knit/core/ownership/collection_ownership.dart';
import 'package:knit/features/collection/domain/collection_models.dart';
import 'package:knit/features/collection/domain/collection_outline.dart';
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
    cards: cards,
  );

  test('ViewAttached loads the given collection', () {
    final (next, effects) = updater.update(
      const CollectionState(),
      const ViewAttached('col-1'),
    );
    expect(next.status, CollectionStatus.loading);
    expect(next.collectionId, 'col-1');
    final effect = effects!.single as LoadCollectionEffect;
    expect(effect.collectionId, 'col-1');
    expect(
      (effect.window as LatestFeedWindow).limit,
      CollectionUpdater.feedPageSize,
    );
  });

  group('feed paging (§8.7)', () {
    const boundary = FeedCursor('a0', 'c0');
    CollectionState partial(List<FeedCard> cards) =>
        ready(cards).copyWith(olderBoundary: boundary);

    test('ViewAttached with a focus card reaches back through it', () {
      final (_, effects) = updater.update(
        const CollectionState(),
        const ViewAttached('col-1', focusCardId: 'hit'),
      );
      final window =
          (effects!.single as LoadCollectionEffect).window as ThroughFeedWindow;
      expect(window.cardId, 'hit');
    });

    test('ReloadRequested resyncs from the oldest loaded card', () {
      final (_, effects) = updater.update(
        partial([card('c1', 'a1'), card('c2', 'a2')]),
        const ReloadRequested(),
      );
      final window =
          (effects!.single as LoadCollectionEffect).window as FromFeedWindow;
      expect(window.cursor, const FeedCursor('a1', 'c1'));
    });

    test('OlderCardsRequested pages from the window top, once', () {
      final (loading, effects) = updater.update(
        partial([card('c1', 'a1'), card('c2', 'a2')]),
        const OlderCardsRequested(),
      );
      expect(loading.loadingOlder, isTrue);
      final effect = effects!.single as LoadOlderCardsEffect;
      expect(effect.before, const FeedCursor('a1', 'c1'));
      expect(effect.limit, CollectionUpdater.feedPageSize);

      final (_, again) = updater.update(loading, const OlderCardsRequested());
      expect(again, isNull);
    });

    test('OlderCardsRequested is a no-op once the head is loaded', () {
      final (_, effects) = updater.update(
        ready([card('c1', 'a1')]),
        const OlderCardsRequested(),
      );
      expect(effects, isNull);
    });

    test('OlderCardsLoaded prepends the page and moves the boundary', () {
      final state = partial([card('c1', 'a1')]).copyWith(loadingOlder: true);
      final (next, effects) = updater.update(
        state,
        OlderCardsLoaded(
          const FeedCursor('a1', 'c1'),
          FeedPage(cards: [card('c0', 'a0', kind: CardKind.image)]),
        ),
      );
      expect(next.cards.map((c) => c.id), ['c0', 'c1']);
      expect(next.hasOlder, isFalse);
      expect(next.loadingOlder, isFalse);
      // The image card in the new page has no attachment id → nothing to show.
      expect((effects!.single as ShowFeedImagesEffect).attachmentIds, isEmpty);
    });

    test('a stale OlderCardsLoaded is dropped', () {
      final state = partial([card('c2', 'a2')]).copyWith(loadingOlder: true);
      final (next, _) = updater.update(
        state,
        OlderCardsLoaded(
          const FeedCursor('a1', 'c1'),
          FeedPage(cards: [card('c0', 'a0')]),
        ),
      );
      expect(next.cards.map((c) => c.id), ['c2']);
      expect(next.loadingOlder, isFalse);
      expect(next.hasOlder, isTrue);
    });

    test('a move to the window top stays above unloaded cards', () {
      final state = partial([
        card('c1', 'a1'),
        card('c2', 'a2'),
      ]).copyWith(reordering: true);
      final (_, effects) = updater.update(state, const CardMoved(1, 0));
      final position = (effects!.single as ReorderCardEffect).position;
      expect(position.compareTo(boundary.position), greaterThan(0));
      expect(position.compareTo('a1'), lessThan(0));
    });

    test('isEmpty is false while older cards remain unloaded', () {
      expect(partial(const []).isEmpty, isFalse);
    });
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
      description: null,
      coverAttachmentId: null,
      cards: [card('c1', 'a0')],
    );
    final (next, effects) = updater.update(
      const CollectionState(),
      CollectionLoaded(data),
    );
    expect(next.status, CollectionStatus.ready);
    expect(next.cards.single.id, 'c1');
    expect(effects!.whereType<ShowFeedImagesEffect>(), hasLength(1));
  });

  group('image thumbnails', () {
    CollectionData dataWith(List<FeedCard> cards, {String? cover}) =>
        CollectionData(
          collectionId: 'col',
          title: 'Notes',
          description: null,
          coverAttachmentId: cover,
          cards: cards,
        );

    FeedCard imageCard(String id, String position, String? attachmentId) =>
        FeedCard(
          id: id,
          kind: CardKind.image,
          position: position,
          attachmentId: attachmentId,
        );

    test('CollectionLoaded shows the window\'s image cards + the cover', () {
      final data = dataWith([
        card('c1', 'a0'),
        imageCard('c2', 'a1', 'att-1'),
        imageCard('c3', 'a2', 'att-2'),
      ], cover: 'cov');
      final (_, effects) = updater.update(
        const CollectionState(),
        CollectionLoaded(data),
      );
      expect(effects!.whereType<ShowFeedImagesEffect>().single.attachmentIds, [
        'att-1',
        'att-2',
      ]);
      expect(effects.whereType<ShowCoverEffect>().single.attachmentId, 'cov');
    });

    test('an image card without an attachment id shows nothing', () {
      final data = dataWith([imageCard('c1', 'a0', null)]);
      final (_, effects) = updater.update(
        const CollectionState(),
        CollectionLoaded(data),
      );
      expect(
        effects!.whereType<ShowFeedImagesEffect>().single.attachmentIds,
        isEmpty,
      );
      expect(effects.whereType<ShowCoverEffect>().single.attachmentId, isNull);
    });

    test('OlderCardsLoaded shows the whole widened window', () {
      final state = ready([imageCard('c2', 'a2', 'att-2')]).copyWith(
        olderBoundary: const FeedCursor('a1', 'c1'),
        loadingOlder: true,
      );
      final (_, effects) = updater.update(
        state,
        OlderCardsLoaded(
          FeedCursor.of(state.cards.first),
          FeedPage(cards: [imageCard('c1', 'a1', 'att-1')]),
        ),
      );
      expect((effects!.single as ShowFeedImagesEffect).attachmentIds, [
        'att-1',
        'att-2',
      ]);
    });

    test('DeactivateFeature releases the page\'s images', () {
      final (_, effects) = updater.update(
        ready(const []),
        const DeactivateFeature(),
      );
      expect(effects!.single, isA<ReleaseImagesEffect>());
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

    test('the full composer keeps a bare URL as a text card', () {
      final (_, effects) = updater.update(
        ready(const []),
        const ComposerSubmitted('https://x.y'),
      );
      final effect = effects!.single as AddCardEffect;
      expect(effect.kind, CardKind.text);
      expect(effect.closesQuickInput, isFalse);
    });

    test('quick input sends a bare URL as a link card and closes after', () {
      final quick = ready(const []).copyWith(quickInput: true);
      final (_, effects) = updater.update(
        quick,
        const ComposerSubmitted('  https://x.y  '),
      );
      final effect = effects!.single as AddCardEffect;
      expect(effect.kind, CardKind.link);
      expect(effect.text, 'https://x.y');
      expect(effect.closesQuickInput, isTrue);

      final (_, textEffects) = updater.update(
        quick,
        const ComposerSubmitted('see https://x.y'),
      );
      expect((textEffects!.single as AddCardEffect).kind, CardKind.text);
    });

    test('quick input closes after an attachment send too', () {
      final (_, effects) = updater.update(
        ready(const []).copyWith(quickInput: true),
        ComposerSubmitted('', images: [image]),
      );
      expect((effects!.single as AddPhotoCardEffect).closesQuickInput, isTrue);
    });

    test('quick input survives the post-load state rebuild', () {
      final (attached, _) = updater.update(
        const CollectionState(),
        const ViewAttached('col', quickInput: true),
      );
      expect(attached.quickInput, isTrue);
      final (loaded, _) = updater.update(
        attached,
        const CollectionLoaded(
          CollectionData(
            collectionId: 'col',
            title: 'Col',
            description: null,
            coverAttachmentId: null,
            cards: [],
          ),
        ),
      );
      expect(loaded.quickInput, isTrue);
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

    test('sending an image emits a photo card with the trimmed caption', () {
      final (next, effects) = updater.update(
        ready([card('c1', 'a0')]),
        ComposerSubmitted('  a caption  ', images: [image]),
      );
      final effect = effects!.single as AddPhotoCardEffect;
      expect(effect.collectionId, 'col');
      expect(effect.position.compareTo('a0') > 0, isTrue);
      expect(effect.caption, 'a caption', reason: 'trimmed');
      expect(effect.images.single, same(image));
      expect(next.cards, hasLength(1), reason: 'the feed waits for the resync');
    });

    test('several staged photos go as one photo card, in order', () {
      final second = PickedImage(
        bytes: Uint8List.fromList([9]),
        mime: 'image/png',
      );
      final (_, effects) = updater.update(
        ready(const []),
        ComposerSubmitted('', images: [image, second]),
      );
      expect((effects!.single as AddPhotoCardEffect).images, [image, second]);
    });

    test('an attachment with blank text carries a null caption', () {
      final (_, effects) = updater.update(
        ready(const []),
        ComposerSubmitted('   ', images: [image]),
      );
      final effect = effects!.single as AddPhotoCardEffect;
      expect(effect.caption, isNull);
      expect(effect.position, 'a0');
    });

    test('sending a clip emits an audio card', () {
      final (_, effects) = updater.update(
        ready([card('c1', 'a0')]),
        ComposerSubmitted('  a note  ', audio: audio),
      );
      final effect = effects!.single as AddAudioCardEffect;
      expect(effect.position.compareTo('a0') > 0, isTrue);
      expect(effect.caption, 'a note');
      expect(effect.audio, same(audio));
    });

    test('sending a file emits a file card', () {
      final (_, effects) = updater.update(
        ready([card('c1', 'a0')]),
        ComposerSubmitted('  a caption  ', file: pickedFile),
      );
      final effect = effects!.single as AddFileCardEffect;
      expect(effect.collectionId, 'col');
      expect(effect.position.compareTo('a0') > 0, isTrue);
      expect(effect.caption, 'a caption');
      expect(effect.file, same(pickedFile));
    });

    test('an image-typed file is sent as a photo card', () {
      final imageFile = PickedFile(
        bytes: Uint8List.fromList([10, 11, 12]),
        mime: 'image/jpeg',
        name: 'holiday.jpg',
      );
      final (_, effects) = updater.update(
        ready([card('c1', 'a0')]),
        ComposerSubmitted('beach', file: imageFile),
      );
      final effect = effects!.single as AddPhotoCardEffect;
      expect(effect.images.single.bytes, imageFile.bytes);
      expect(effect.images.single.mime, 'image/jpeg');
      expect(effect.caption, 'beach');
      expect(effect.position.compareTo('a0') > 0, isTrue);
    });

    test('an audio-typed file is sent as an audio card', () {
      final audioFile = PickedFile(
        bytes: Uint8List.fromList([13, 14, 15]),
        mime: 'audio/mpeg',
        name: 'song.mp3',
      );
      final (_, effects) = updater.update(
        ready(const []),
        ComposerSubmitted('  ', file: audioFile),
      );
      final effect = effects!.single as AddAudioCardEffect;
      expect(effect.audio.bytes, audioFile.bytes);
      expect(effect.audio.mime, 'audio/mpeg');
      expect(effect.audio.name, 'song.mp3');
      expect(effect.caption, isNull);
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

    test('delete carries an image card\'s attachment id for GC', () {
      const img = FeedCard(
        id: 'c1',
        kind: CardKind.image,
        position: 'a0',
        attachmentId: 'att-1',
      );
      final (_, effects) = updater.update(
        ready([img]),
        const CardDeleteRequested('c1'),
      );
      final eff = effects!.single as DeleteCardEffect;
      expect(eff.cardId, 'c1');
      expect(eff.attachmentIds, ['att-1']);
    });

    test('delete carries every image of a several-photo card for GC', () {
      const img = FeedCard(
        id: 'c1',
        kind: CardKind.image,
        position: 'a0',
        attachmentId: 'att-1',
        moreAttachmentIds: ['att-2'],
      );
      final (_, effects) = updater.update(
        ready([img]),
        const CardDeleteRequested('c1'),
      );
      expect((effects!.single as DeleteCardEffect).attachmentIds, [
        'att-1',
        'att-2',
      ]);
    });

    test('deleting the collection emits a delete for this collection', () {
      final (next, effects) = updater.update(
        ready([card('c1', 'a0')]),
        const CollectionDeleteRequested(),
      );
      expect(next.cards, hasLength(1));
      expect((effects!.single as DeleteCollectionEffect).collectionId, 'col');
    });

    test('delete of a text card carries no attachment id', () {
      final (_, effects) = updater.update(
        ready([card('c2', 'a0')]),
        const CardDeleteRequested('c2'),
      );
      expect((effects!.single as DeleteCardEffect).attachmentIds, isEmpty);
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
      expect(effect.attachmentIds, isEmpty);
    });

    test('an image card shares the photo plus its caption, date-stamped', () {
      final (_, effects) = updater.update(
        ready([photo(v7Id, caption: 'a caption')]),
        const CardShareRequested(v7Id),
      );
      final effect = effects!.single as ShareCardEffect;
      expect(effect.text, 'a caption');
      expect(effect.attachmentIds, ['att-1']);
      expect(effect.imageBaseName, matches(r'^\d{4}-\d{2}-\d{2}-knit$'));
    });

    test('an image card with several photos shares them all, in order', () {
      const many = FeedCard(
        id: v7Id,
        kind: CardKind.image,
        position: 'a0',
        attachmentId: 'att-1',
        moreAttachmentIds: ['att-2', 'att-3'],
      );
      final (_, effects) = updater.update(
        ready([many]),
        const CardShareRequested(v7Id),
      );
      expect((effects!.single as ShareCardEffect).attachmentIds, [
        'att-1',
        'att-2',
        'att-3',
      ]);
    });

    test('an image card with no caption shares the photo alone', () {
      final (_, effects) = updater.update(
        ready([photo(v7Id)]),
        const CardShareRequested(v7Id),
      );
      final effect = effects!.single as ShareCardEffect;
      expect(effect.text, isNull);
      expect(effect.attachmentIds, ['att-1']);
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
      expect(effect.attachmentIds, ['att-9']);
      expect(effect.fileName, 'report.pdf');
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
      // onReorderItem reports newIndex as the final, post-removal slot.
      final (next, effects) = updater.update(state, const CardMoved(0, 2));
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
        description: null,
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
        description: null,
        coverAttachmentId: null,
        cards: [card('c1', 'a0')],
      );
      final (next, _) = updater.update(state, CollectionLoaded(data));
      expect(next.reordering, isFalse);
    });
  });

  group('CardKind.forFileMime', () {
    test('image/* mimes classify as image cards', () {
      expect(CardKind.forFileMime('image/png'), CardKind.image);
      expect(CardKind.forFileMime('IMAGE/JPEG'), CardKind.image);
    });

    test('audio/* mimes classify as audio cards', () {
      expect(CardKind.forFileMime('audio/mp4'), CardKind.audio);
      expect(CardKind.forFileMime('audio/mpeg'), CardKind.audio);
    });

    test('everything else classifies as a generic file card', () {
      expect(CardKind.forFileMime('application/pdf'), CardKind.file);
      expect(CardKind.forFileMime('video/mp4'), CardKind.file);
      expect(CardKind.forFileMime(''), CardKind.file);
    });
  });

  group('CardKind.forText', () {
    test('a lone http(s) URL with a host is a link card', () {
      expect(CardKind.forText('https://x.y/p?q=1'), CardKind.link);
      expect(CardKind.forText('HTTP://x.y'), CardKind.link);
    });

    test('anything else is a text card', () {
      expect(CardKind.forText('see https://x.y'), CardKind.text);
      expect(CardKind.forText('ftp://x.y'), CardKind.text);
      expect(CardKind.forText('https://'), CardKind.text);
      expect(CardKind.forText('hello'), CardKind.text);
    });
  });

  group('multi-select + move to another collection', () {
    const target = MoveTarget(collectionId: 'other', title: 'Other');
    final cards = [card('c1', 'a0'), card('c2', 'a1'), card('c3', 'a2')];

    CollectionState selecting(Set<String> ids) =>
        ready(cards).copyWith(selectedCardIds: ids);

    test('a toggle enters selection; toggling the last card leaves it', () {
      var (next, effects) = updater.update(
        ready(cards),
        const CardSelectionToggled('c2'),
      );
      expect(next.selecting, isTrue);
      expect(next.selectedCardIds, {'c2'});
      expect(effects, isNull);

      (next, _) = updater.update(next, const CardSelectionToggled('c1'));
      expect(next.selectedCardIds, {'c1', 'c2'});
      (next, _) = updater.update(next, const CardSelectionToggled('c1'));
      (next, _) = updater.update(next, const CardSelectionToggled('c2'));
      expect(next.selecting, isFalse);
    });

    test('toggling is inert in reorder mode or for an unknown card', () {
      final reordering = ready(cards).copyWith(reordering: true);
      expect(
        updater.update(reordering, const CardSelectionToggled('c1')).$1,
        same(reordering),
      );
      final idle = ready(cards);
      expect(
        updater.update(idle, const CardSelectionToggled('nope')).$1,
        same(idle),
      );
    });

    test('select all picks every loaded card; clear leaves the mode', () {
      final (all, _) = updater.update(
        selecting({'c1'}),
        const AllCardsSelected(),
      );
      expect(all.selectedCardIds, {'c1', 'c2', 'c3'});
      final (cleared, _) = updater.update(all, const SelectionCleared());
      expect(cleared.selecting, isFalse);
    });

    test('starting reorder drops the selection', () {
      final (next, _) = updater.update(selecting({'c1'}), const StartReorder());
      expect(next.reordering, isTrue);
      expect(next.selecting, isFalse);
    });

    test('a resync keeps the selection minus cards that left the feed', () {
      final (next, _) = updater.update(
        selecting({'c1', 'c3'}),
        CollectionLoaded(
          CollectionData(
            collectionId: 'col',
            title: 'T',
            description: null,
            coverAttachmentId: null,
            cards: [cards[0], cards[1]],
          ),
        ),
      );
      expect(next.selectedCardIds, {'c1'});
    });

    test('loading targets excludes the current collection', () {
      final (loading, effects) = updater.update(
        selecting({'c1'}),
        const MoveTargetsRequested(),
      );
      expect(loading.moveTargetsStatus, MoveTargetsStatus.loading);
      expect(effects!.single, isA<LoadMoveTargetsEffect>());

      final (loaded, _) = updater.update(
        loading,
        const MoveTargetsLoaded([
          MoveTarget(collectionId: 'col', title: 'This'),
          target,
        ]),
      );
      expect(loaded.moveTargetsStatus, MoveTargetsStatus.ready);
      expect(loaded.moveTargets, [target]);
    });

    test('choosing a target reads its tail', () {
      final (next, effects) = updater.update(
        selecting({'c1'}),
        const MoveTargetChosen(target),
      );
      expect(next.moveTargetsStatus, MoveTargetsStatus.idle);
      expect((effects!.single as LoadMoveTargetTailEffect).target, target);
    });

    test('choosing the current collection or with no selection is a no-op', () {
      final (_, sameCol) = updater.update(
        selecting({'c1'}),
        const MoveTargetChosen(MoveTarget(collectionId: 'col', title: 'T')),
      );
      expect(sameCol, isNull);
      final (_, none) = updater.update(
        ready(cards),
        const MoveTargetChosen(target),
      );
      expect(none, isNull);
    });

    test('a new collection is created as the target', () {
      final (next, effects) = updater.update(
        selecting({'c1'}),
        const MoveToNewCollectionChosen('  Fresh  '),
      );
      expect(next.moveTargetsStatus, MoveTargetsStatus.idle);
      expect((effects!.single as CreateMoveTargetEffect).title, 'Fresh');
    });

    test('a blank title or no selection creates nothing', () {
      final (_, blank) = updater.update(
        selecting({'c1'}),
        const MoveToNewCollectionChosen('   '),
      );
      expect(blank, isNull);
      final (_, none) = updater.update(
        ready(cards),
        const MoveToNewCollectionChosen('Fresh'),
      );
      expect(none, isNull);
    });

    test('the tail appends the selection in feed order, not tap order', () {
      // Selected c3 first, then c1: they still land as c1, c3.
      final (next, effects) = updater.update(
        selecting({'c3', 'c1'}),
        const MoveTargetTailLoaded(target, 'a5'),
      );
      final move = effects!.single as MoveCardsEffect;
      expect(move.target, target);
      expect(move.positions.keys, ['c1', 'c3']);
      final p1 = move.positions['c1']!;
      final p3 = move.positions['c3']!;
      expect(p1.compareTo('a5'), greaterThan(0));
      expect(p3.compareTo(p1), greaterThan(0));
      // Removed from this feed optimistically; selection mode is over.
      expect(next.cards.map((c) => c.id), ['c2']);
      expect(next.selecting, isFalse);
    });

    test('an empty target starts at the first key', () {
      final (_, effects) = updater.update(
        selecting({'c2'}),
        const MoveTargetTailLoaded(target, null),
      );
      final move = effects!.single as MoveCardsEffect;
      expect(move.positions, {'c2': FractionalIndex.first()});
    });
  });

  group('settle (§3.3)', () {
    FeedCard settledCard(String id, String position) => FeedCard(
      id: id,
      kind: CardKind.text,
      position: position,
      text: id,
      settledAt: 1000,
    );

    test('the actions sheet settles a live card', () {
      final (next, effects) = updater.update(
        ready([card('c1', 'a0')]),
        const CardSettleToggled('c1'),
      );
      final effect = effects!.single as SettleCardsEffect;
      expect(effect.cardIds, ['c1']);
      expect(effect.settled, isTrue);
      expect(next.cards.single.settled, isFalse, reason: 'no optimism');
    });

    test('the actions sheet unsettles a settled card', () {
      final (_, effects) = updater.update(
        ready([settledCard('c1', 'a0')]),
        const CardSettleToggled('c1'),
      );
      final effect = effects!.single as SettleCardsEffect;
      expect(effect.cardIds, ['c1']);
      expect(effect.settled, isFalse);
    });

    test('an unknown card is a no-op', () {
      final (_, effects) = updater.update(
        ready([card('c1', 'a0')]),
        const CardSettleToggled('gone'),
      );
      expect(effects, isNull);
    });

    test('a mixed selection settles only its live cards, then clears', () {
      final state = ready([
        settledCard('c1', 'a0'),
        card('c2', 'a1'),
        card('c3', 'a2'),
      ]).copyWith(selectedCardIds: {'c1', 'c2'});
      expect(state.selectionAllSettled, isFalse);

      final (next, effects) = updater.update(
        state,
        const SelectionSettleRequested(),
      );
      final effect = effects!.single as SettleCardsEffect;
      expect(effect.cardIds, ['c2']);
      expect(effect.settled, isTrue);
      expect(next.selecting, isFalse);
    });

    test('an all-settled selection unsettles them all', () {
      final state = ready([
        settledCard('c1', 'a0'),
        settledCard('c2', 'a1'),
        card('c3', 'a2'),
      ]).copyWith(selectedCardIds: {'c1', 'c2'});
      expect(state.selectionAllSettled, isTrue);

      final (_, effects) = updater.update(
        state,
        const SelectionSettleRequested(),
      );
      final effect = effects!.single as SettleCardsEffect;
      expect(effect.cardIds, ['c1', 'c2']);
      expect(effect.settled, isFalse);
    });

    test('outside selection mode it does nothing', () {
      final (_, effects) = updater.update(
        ready([card('c1', 'a0')]),
        const SelectionSettleRequested(),
      );
      expect(effects, isNull);
    });
    group('delete selected cards', () {
      test(
        'deletes the selected cards with their attachments, then clears',
        () {
          final state = ready([
            card('c1', 'a0'),
            card('c2', 'a1'),
            card('c3', 'a2'),
          ]).copyWith(selectedCardIds: {'c3', 'c1'});

          final (next, effects) = updater.update(
            state,
            const SelectionDeleteRequested(),
          );
          final effect = effects!.single as DeleteCardsEffect;
          expect(effect.cardIds, ['c1', 'c3'], reason: 'feed order');
          expect(next.selecting, isFalse);
        },
      );

      test('outside selection mode it does nothing', () {
        final (_, effects) = updater.update(
          ready([card('c1', 'a0')]),
          const SelectionDeleteRequested(),
        );
        expect(effects, isNull);
      });
    });
  });

  group('emphasize (§3.3)', () {
    FeedCard marked(String id, String position, {bool settled = false}) =>
        FeedCard(
          id: id,
          kind: CardKind.text,
          position: position,
          text: id,
          settledAt: settled ? 1000 : null,
          emphasizedAt: settled ? null : 1000,
        );

    test('the actions sheet emphasizes a live card', () {
      final (next, effects) = updater.update(
        ready([card('c1', 'a0')]),
        const CardEmphasisToggled('c1'),
      );
      final effect = effects!.single as EmphasizeCardsEffect;
      expect(effect.cardIds, ['c1']);
      expect(effect.emphasized, isTrue);
      expect(next.cards.single.emphasized, isFalse, reason: 'no optimism');
    });

    test('the actions sheet unemphasizes an emphasized card', () {
      final (_, effects) = updater.update(
        ready([marked('c1', 'a0')]),
        const CardEmphasisToggled('c1'),
      );
      final effect = effects!.single as EmphasizeCardsEffect;
      expect(effect.emphasized, isFalse);
    });

    test('a settled card is emphasized (the write unsettles it)', () {
      final (_, effects) = updater.update(
        ready([marked('c1', 'a0', settled: true)]),
        const CardEmphasisToggled('c1'),
      );
      final effect = effects!.single as EmphasizeCardsEffect;
      expect(effect.cardIds, ['c1']);
      expect(effect.emphasized, isTrue);
    });

    test('a mixed selection emphasizes the rest, then clears', () {
      final state = ready([
        marked('c1', 'a0'),
        card('c2', 'a1'),
        marked('c3', 'a2', settled: true),
      ]).copyWith(selectedCardIds: {'c1', 'c2', 'c3'});
      expect(state.selectionAllEmphasized, isFalse);

      final (next, effects) = updater.update(
        state,
        const SelectionEmphasisRequested(),
      );
      final effect = effects!.single as EmphasizeCardsEffect;
      expect(effect.cardIds, ['c2', 'c3']);
      expect(effect.emphasized, isTrue);
      expect(next.selecting, isFalse);
    });

    test('an all-emphasized selection unemphasizes them all', () {
      final state = ready([
        marked('c1', 'a0'),
        marked('c2', 'a1'),
      ]).copyWith(selectedCardIds: {'c1', 'c2'});
      expect(state.selectionAllEmphasized, isTrue);

      final (_, effects) = updater.update(
        state,
        const SelectionEmphasisRequested(),
      );
      final effect = effects!.single as EmphasizeCardsEffect;
      expect(effect.cardIds, ['c1', 'c2']);
      expect(effect.emphasized, isFalse);
    });

    test('outside selection mode it does nothing', () {
      final (_, effects) = updater.update(
        ready([card('c1', 'a0')]),
        const SelectionEmphasisRequested(),
      );
      expect(effects, isNull);
    });
  });

  group('selection copy text', () {
    test('joins the selected texts in feed order, one per line', () {
      final state = ready([
        card('c1', 'a0'),
        card('c2', 'a1'),
        card('c3', 'a2'),
      ]).copyWith(selectedCardIds: {'c3', 'c1'});
      expect(state.selectionCopyText, 'c1\nc3');
    });

    test('trims texts and skips cards without text', () {
      final state = ready([
        const FeedCard(
          id: 'c1',
          kind: CardKind.text,
          position: 'a0',
          text: '  first  ',
        ),
        const FeedCard(id: 'c2', kind: CardKind.image, position: 'a1'),
        const FeedCard(
          id: 'c3',
          kind: CardKind.text,
          position: 'a2',
          text: ' ',
        ),
        card('c4', 'a3'),
      ]).copyWith(selectedCardIds: {'c1', 'c2', 'c3', 'c4'});
      expect(state.selectionCopyText, 'first\nc4');
    });

    test('is empty when no selected card has text', () {
      final state = ready([
        const FeedCard(id: 'c1', kind: CardKind.image, position: 'a0'),
      ]).copyWith(selectedCardIds: {'c1'});
      expect(state.selectionCopyText, isEmpty);
    });
  });

  group('outline (§4.2)', () {
    FeedCard heading(String id, String position) => FeedCard(
      id: id,
      kind: CardKind.text,
      position: position,
      text: id,
      emphasizedAt: 1,
    );

    test('opening loads the whole collection\'s cards', () {
      final (next, effects) = updater.update(
        ready([card('c1', 'a1')]),
        const OutlineRequested(),
      );
      expect(next.outlineStatus, OutlineStatus.loading);
      expect((effects!.single as LoadOutlineEffect).collectionId, 'col');
    });

    test('the loaded cards become the emphasized headings, in order', () {
      final (next, effects) = updater.update(
        ready([]).copyWith(outlineStatus: OutlineStatus.loading),
        OutlineCardsLoaded([
          heading('h1', 'a1'),
          card('c2', 'a2'),
          heading('h3', 'a3'),
        ]),
      );
      expect(effects, isNull);
      expect(next.outlineStatus, OutlineStatus.ready);
      expect(next.outline, const [
        OutlineEntry(cardId: 'h1', kind: CardKind.text, label: 'h1'),
        OutlineEntry(cardId: 'h3', kind: CardKind.text, label: 'h3'),
      ]);
    });

    test('a failed load says so', () {
      final (next, _) = updater.update(
        ready([]).copyWith(outlineStatus: OutlineStatus.loading),
        const OutlineLoadFailed(),
      );
      expect(next.outlineStatus, OutlineStatus.failed);
    });

    test('works in a read-only (imported) collection', () {
      final imported = ready([
        card('c1', 'a1'),
      ]).copyWith(ownership: CollectionOwnership.imported);
      final (opened, effects) = updater.update(
        imported,
        const OutlineRequested(),
      );
      expect(effects!.single, isA<LoadOutlineEffect>());
      final (jumped, _) = updater.update(
        opened,
        const OutlineEntryChosen('c1'),
      );
      expect(jumped.focus?.cardId, 'c1');
    });

    test('choosing a loaded card focuses it without a load', () {
      final (next, effects) = updater.update(
        ready([card('c1', 'a1'), card('c2', 'a2')]),
        const OutlineEntryChosen('c1'),
      );
      expect(effects, isNull);
      expect(next.focus?.cardId, 'c1');
    });

    test('choosing the same card again is a new request', () {
      final (first, _) = updater.update(
        ready([card('c1', 'a1')]),
        const OutlineEntryChosen('c1'),
      );
      final (second, _) = updater.update(first, const OutlineEntryChosen('c1'));
      expect(second.focus, isNot(first.focus));
      expect(second.focus?.cardId, 'c1');
    });

    test('choosing an unloaded card loads the feed down to it', () {
      final (next, effects) = updater.update(
        ready([
          card('c9', 'a9'),
        ]).copyWith(olderBoundary: const FeedCursor('a8', 'c8')),
        const OutlineEntryChosen('c1'),
      );
      expect(next.focus?.cardId, 'c1');
      final load = effects!.single as LoadCollectionEffect;
      expect(load.collectionId, 'col');
      final window = load.window as ThroughFeedWindow;
      expect(window.cardId, 'c1');
      expect(window.minLimit, CollectionUpdater.feedPageSize);
    });

    test('the focus survives the load that brings its card', () {
      final (chosen, _) = updater.update(
        ready([card('c9', 'a9')]),
        const OutlineEntryChosen('c1'),
      );
      final (loaded, _) = updater.update(
        chosen,
        CollectionLoaded(
          CollectionData(
            collectionId: 'col',
            title: 'T',
            description: null,
            coverAttachmentId: null,
            cards: [card('c1', 'a1'), card('c9', 'a9')],
          ),
        ),
      );
      expect(loaded.focus, chosen.focus);
      expect(loaded.cards.map((c) => c.id), ['c1', 'c9']);
    });

    test('a search-hit entry is a focus request too', () {
      final (next, _) = updater.update(
        const CollectionState(),
        const ViewAttached('col-1', focusCardId: 'hit'),
      );
      expect(next.focus?.cardId, 'hit');
    });
  });
}
