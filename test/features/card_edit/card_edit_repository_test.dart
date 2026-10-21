import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:knit/app/app_graph.dart';
import 'package:knit/core/attachments/attachments.dart';
import 'package:knit/core/ids/uuid_id_generator.dart';
import 'package:knit/features/card_edit/infra/sync_store_card_edit_links_read_repository.dart';
import 'package:knit/features/card_edit/infra/sync_store_card_edit_timeline_preview_read_repository.dart';
import 'package:knit/features/card_edit/infra/sync_store_card_edit_write_repository.dart';
import 'package:knit/features/card_links/infra/sync_store_card_links_write_repository.dart';
import 'package:knit/features/collection/domain/collection_models.dart';
import 'package:knit/features/collection/infra/sync_store_collection_read_repository.dart';
import 'package:knit/features/collection/infra/sync_store_collection_write_repository.dart';
import 'package:knit/features/connections/domain/connections_models.dart';
import 'package:knit/features/timeline/infra/sync_store_timeline_write_repository.dart';
import 'package:knit/sync/sync.dart';

/// Drives the §4.3 card-edit writes/reads through their repositories over a real
/// in-memory [SyncStore]: the text edit lands in the feed, links manage the full
/// (card→card) scope with the §8.6.1 broken derivation, and the image flips the
/// card `kind`/`attachment_id`.
void main() {
  late AppGraph graph;
  late SyncStore store;
  late SyncStoreTimelineWriteRepository timelineWrite;
  late SyncStoreCollectionReadRepository read;
  late SyncStoreCollectionWriteRepository collectionWrite;
  late SyncStoreCardEditWriteRepository cardEditWrite;
  late SyncStoreCardEditLinksReadRepository linksRead;
  late SyncStoreCardLinksWriteRepository linksWrite;
  const ids = UuidIdGenerator();

  setUp(() async {
    graph = AppGraph();
    store = SyncStore.inMemory();
    await store.open();
    graph.bindStore(store);
    graph.bindBlobStore(InMemoryAttachmentBlobStore());
    timelineWrite = SyncStoreTimelineWriteRepository(graph: graph, ids: ids);
    read = SyncStoreCollectionReadRepository(graph: graph);
    collectionWrite = SyncStoreCollectionWriteRepository(
      graph: graph,
      ids: ids,
    );
    cardEditWrite = SyncStoreCardEditWriteRepository(graph: graph);
    linksRead = SyncStoreCardEditLinksReadRepository(graph: graph);
    linksWrite = SyncStoreCardLinksWriteRepository(graph: graph, ids: ids);
  });

  Future<String> newCard(String colId, String text) async =>
      (await collectionWrite.addCard(
        collectionId: colId,
        kind: CardKind.text,
        position: 'a0',
        text: text,
      )).getOrThrow();

  test('editCard updates the card body in the feed', () async {
    final colId = (await timelineWrite.createCollection(
      'Espresso',
    )).getOrThrow();
    final cardId = await newCard(colId, 'first');

    final result = await cardEditWrite.editCard(
      cardId: cardId,
      text: 'first (edited)',
    );
    expect(result.getOrThrow(), cardId);

    final data = (await read.loadCollection(colId)).getOrThrow();
    expect(data.cards.single.text, 'first (edited)');
  });

  test('a Connection card takes a label and gives it back', () async {
    final index = (await timelineWrite.createCollection('Index')).getOrThrow();
    final trips = (await timelineWrite.createCollection('Trips')).getOrThrow();
    final cardId = (await collectionWrite.addConnectionCard(
      collectionId: index,
      position: 'a0',
      targetCollectionId: trips,
    )).getOrThrow();

    await cardEditWrite.editCard(
      cardId: cardId,
      text: 'Next summer',
      kind: CardKind.text,
    );
    var card = (await read.loadCollection(index)).getOrThrow().cards.single;
    expect((card.kind, card.text), (CardKind.text, 'Next summer'));
    expect(card.collectionLink?.caption, 'Next summer');

    await cardEditWrite.editCard(cardId: cardId, kind: CardKind.link);
    card = (await read.loadCollection(index)).getOrThrow().cards.single;
    expect((card.kind, card.text), (CardKind.link, null));
    expect(card.collectionLink?.collectionId, trips);
  });

  test('setCardSettled settles and unsettles, keeping the text', () async {
    final colId = (await timelineWrite.createCollection(
      'Espresso',
    )).getOrThrow();
    final cardId = await newCard(colId, 'pulled the shot');

    await cardEditWrite.setCardSettled(cardId: cardId, settled: true);
    var card = (await read.loadCollection(colId)).getOrThrow().cards.single;
    expect(card.settled, isTrue);
    expect(card.text, 'pulled the shot');

    await cardEditWrite.setCardSettled(cardId: cardId, settled: false);
    card = (await read.loadCollection(colId)).getOrThrow().cards.single;
    expect(card.settled, isFalse);
  });

  group('links', () {
    test(
      'add a card→collection and a card→card link, then read them back',
      () async {
        final colA = (await timelineWrite.createCollection('A')).getOrThrow();
        final colB = (await timelineWrite.createCollection('B')).getOrThrow();
        final source = await newCard(colA, 'source');
        final targetCard = await newCard(colB, 'target card');

        await linksWrite.addLink(
          sourceCardId: source,
          targetKind: ConnectedEntityKind.collection,
          targetId: colB,
        );
        await linksWrite.addLink(
          sourceCardId: source,
          targetKind: ConnectedEntityKind.card,
          targetId: targetCard,
        );

        final links = (await linksRead.linksOf(source)).getOrThrow();
        expect(links, hasLength(2));
        expect(
          links.every((l) => l.direction == ConnectionDirection.outgoing),
          isTrue,
        );

        final toCol = links.firstWhere(
          (l) => l.otherKind == ConnectedEntityKind.collection,
        );
        expect((toCol.otherId, toCol.label, toCol.broken), (colB, 'B', false));

        final toCard = links.firstWhere(
          (l) => l.otherKind == ConnectedEntityKind.card,
        );
        expect(
          (toCard.otherId, toCard.label, toCard.broken),
          (targetCard, 'target card', false),
        );
      },
    );

    test('a link to a deleted target reads back as broken (§8.6.1)', () async {
      final colA = (await timelineWrite.createCollection('A')).getOrThrow();
      final colB = (await timelineWrite.createCollection('B')).getOrThrow();
      final source = await newCard(colA, 'source');
      final targetCard = await newCard(colB, 'doomed');

      await linksWrite.addLink(
        sourceCardId: source,
        targetKind: ConnectedEntityKind.card,
        targetId: targetCard,
      );
      await collectionWrite.deleteCard(targetCard);

      final link = (await linksRead.linksOf(source)).getOrThrow().single;
      expect(link.broken, isTrue);
      expect(link.label, isNull);
    });

    test('removeLink deletes only the link record', () async {
      final colA = (await timelineWrite.createCollection('A')).getOrThrow();
      final source = await newCard(colA, 'source');
      final linkId = (await linksWrite.addLink(
        sourceCardId: source,
        targetKind: ConnectedEntityKind.collection,
        targetId: colA,
      )).getOrThrow();

      await linksWrite.removeLink(linkId);

      expect((await linksRead.linksOf(source)).getOrThrow(), isEmpty);
      // The source card is untouched.
      final data = (await read.loadCollection(colA)).getOrThrow();
      expect(data.cards.single.id, source);
    });
  });

  group('attachment', () {
    PickedImage png(List<int> b) =>
        PickedImage(bytes: Uint8List.fromList(b), mime: 'image/png');

    test(
      'setCardAttachment flips kind to image and points at the attachment',
      () async {
        final colA = (await timelineWrite.createCollection('A')).getOrThrow();
        final cardId = await newCard(colA, 'note');
        final attachmentWrite = SyncStoreAttachmentWriteRepository(
          graph: graph,
          ids: ids,
        );
        final attId = (await attachmentWrite.createFromPicked(
          png([1, 2, 3]),
        )).getOrThrow();

        await cardEditWrite.setCardAttachment(
          cardId: cardId,
          attachmentId: attId,
          kind: CardKind.image,
        );

        final snap = (await store.get(EntityType.card, cardId))!;
        expect(snap.content['kind'], 'image');
        expect(snap.content['attachment_id'], attId);
        expect(snap.content['text'], 'note'); // text preserved by the overlay

        final data = (await read.loadCollection(colA)).getOrThrow();
        expect(data.cards.single.attachmentId, attId);
        expect(data.cards.single.kind, CardKind.image);
      },
    );

    test(
      'setCardImages keeps several images in order; a file drops them',
      () async {
        final colA = (await timelineWrite.createCollection('A')).getOrThrow();
        final cardId = await newCard(colA, 'note');
        final attachmentWrite = SyncStoreAttachmentWriteRepository(
          graph: graph,
          ids: ids,
        );
        final a1 = (await attachmentWrite.createFromPicked(
          png([1]),
        )).getOrThrow();
        final a2 = (await attachmentWrite.createFromPicked(
          png([2]),
        )).getOrThrow();
        final a3 = (await attachmentWrite.createFromPicked(
          png([3]),
        )).getOrThrow();

        await cardEditWrite.setCardImages(
          cardId: cardId,
          attachmentIds: [a1, a2, a3],
        );
        final card = (await read.loadCollection(
          colA,
        )).getOrThrow().cards.single;
        expect(card.kind, CardKind.image);
        expect(card.imageIds, [a1, a2, a3]);
        expect(card.text, 'note');

        await cardEditWrite.setCardAttachment(
          cardId: cardId,
          attachmentId: a1,
          kind: CardKind.file,
        );
        final file = (await read.loadCollection(
          colA,
        )).getOrThrow().cards.single;
        expect(file.attachmentIds, [a1]);
      },
    );

    test('setCardAttachment can flip a card to a file attachment', () async {
      final colA = (await timelineWrite.createCollection('A')).getOrThrow();
      final cardId = await newCard(colA, 'note');
      final attachmentWrite = SyncStoreAttachmentWriteRepository(
        graph: graph,
        ids: ids,
      );
      final attId = (await attachmentWrite.createFromFile(
        PickedFile(
          bytes: Uint8List.fromList([7, 7, 7]),
          mime: 'application/pdf',
          name: 'report.pdf',
        ),
      )).getOrThrow();

      await cardEditWrite.setCardAttachment(
        cardId: cardId,
        attachmentId: attId,
        kind: CardKind.file,
      );

      final snap = (await store.get(EntityType.card, cardId))!;
      expect(snap.content['kind'], 'file');
      expect(snap.content['attachment_id'], attId);

      final data = (await read.loadCollection(colA)).getOrThrow();
      expect(data.cards.single.kind, CardKind.file);
      expect(data.cards.single.fileName, 'report.pdf');
    });

    test(
      'removeCardAttachment clears the attachment and flips kind back to text',
      () async {
        final colA = (await timelineWrite.createCollection('A')).getOrThrow();
        final cardId = await newCard(colA, 'note');
        final attachmentWrite = SyncStoreAttachmentWriteRepository(
          graph: graph,
          ids: ids,
        );
        final attId = (await attachmentWrite.createFromPicked(
          png([4, 5]),
        )).getOrThrow();
        await cardEditWrite.setCardAttachment(
          cardId: cardId,
          attachmentId: attId,
          kind: CardKind.image,
        );

        await cardEditWrite.removeCardAttachment(cardId: cardId);

        final snap = (await store.get(EntityType.card, cardId))!;
        expect(snap.content['kind'], 'text');
        expect(snap.content['attachment_id'], isNull);

        final data = (await read.loadCollection(colA)).getOrThrow();
        expect(data.cards.single.attachmentId, isNull);
        expect(data.cards.single.kind, CardKind.text);
      },
    );
  });

  group('timeline preview', () {
    test('only the most recently added live card is the preview', () async {
      final preview = SyncStoreCardEditTimelinePreviewReadRepository(
        graph: graph,
      );
      Future<bool> isPreview(String cardId, String colId) async =>
          (await preview.isTimelinePreview(
            cardId: cardId,
            collectionId: colId,
          )).getOrThrow();

      final colId = (await timelineWrite.createCollection('Tea')).getOrThrow();
      final older = await newCard(colId, 'older');
      // A later millisecond, so created_at (not the id tie-break) decides.
      await Future<void>.delayed(const Duration(milliseconds: 5));
      final newer = await newCard(colId, 'newer');

      expect(await isPreview(newer, colId), isTrue);
      expect(await isPreview(older, colId), isFalse);

      // Deleting the newest hands the preview back to the older card.
      await store.delete(EntityType.card, newer);
      expect(await isPreview(older, colId), isTrue);
    });
  });
}
