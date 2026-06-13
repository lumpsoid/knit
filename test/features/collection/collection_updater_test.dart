import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:knit/features/collection/domain/collection_models.dart';
import 'package:knit/features/collection/presentation/collection_action.dart';
import 'package:knit/features/collection/presentation/collection_effect.dart';
import 'package:knit/features/collection/presentation/collection_state.dart';
import 'package:knit/features/collection/presentation/collection_updater.dart';

void main() {
  const updater = CollectionUpdater();

  FeedCard card(String id, String position, {CardKind kind = CardKind.text}) =>
      FeedCard(id: id, kind: kind, position: position, text: id);

  CollectionState ready(List<FeedCard> cards) => CollectionState(
        status: CollectionStatus.ready,
        collectionId: 'col',
        title: 'Notes',
        cards: cards,
      );

  test('ViewAttached loads the given collection', () {
    final (next, effects) =
        updater.update(const CollectionState(), const ViewAttached('col-1'));
    expect(next.status, CollectionStatus.loading);
    expect(next.collectionId, 'col-1');
    expect((effects!.single as LoadCollectionEffect).collectionId, 'col-1');
  });

  test('ReloadRequested is a no-op before a collection is set', () {
    final (_, effects) =
        updater.update(const CollectionState(), const ReloadRequested());
    expect(effects, isNull);
  });

  test('CollectionLoaded becomes ready with the feed', () {
    final data = CollectionData(
      collectionId: 'col',
      title: 'Notes',
      coverAttachmentId: null,
      cards: [card('c1', 'a0')],
      linkTargets: const [],
    );
    final (next, effects) =
        updater.update(const CollectionState(), CollectionLoaded(data));
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
          linkTargets: const [],
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
      final (_, effects) =
          updater.update(const CollectionState(), CollectionLoaded(data));
      final ids = effects!
          .whereType<LoadImageBytesEffect>()
          .map((e) => e.attachmentId)
          .toList();
      expect(ids, ['att-1', 'att-2']);
    });

    test('an image card without an attachment id loads nothing', () {
      final data = dataWith([imageCard('c1', 'a0', null)]);
      final (_, effects) =
          updater.update(const CollectionState(), CollectionLoaded(data));
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
      final (_, effects) =
          updater.update(ready(const []), const ComposerSubmitted('hi'));
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
      final (_, effects) =
          updater.update(ready(const []), const ComposerSubmitted('   '));
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
  });

  group('delete / link', () {
    test('delete emits DeleteCardEffect', () {
      final (_, effects) = updater.update(
        ready([card('c1', 'a0')]),
        const CardDeleteRequested('c1'),
      );
      expect((effects!.single as DeleteCardEffect).cardId, 'c1');
    });

    test('link request emits LinkEffect', () {
      final (_, effects) = updater.update(
        ready([card('c1', 'a0')]),
        const LinkRequested(cardId: 'c1', targetCollectionId: 'col-2'),
      );
      final effect = effects!.single as LinkEffect;
      expect((effect.cardId, effect.targetCollectionId), ('c1', 'col-2'));
    });
  });

  group('reorder mode', () {
    test('start / end toggles the mode flag', () {
      final (started, _) =
          updater.update(ready(const []), const StartReorder());
      expect(started.reordering, isTrue);
      final (ended, _) = updater.update(started, const EndReorder());
      expect(ended.reordering, isFalse);
    });

    test('moving a card to the end re-keys it after its new predecessor', () {
      final state = ready([card('c1', 'a0'), card('c2', 'a1'), card('c3', 'a2')]);
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
      final state = ready([card('c1', 'a0'), card('c2', 'a1'), card('c3', 'a2')]);
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
