import 'dart:typed_data';

import 'package:effect_emitter/effect_emitter.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:knit/app/app_graph.dart';
import 'package:knit/core/attachments/attachments.dart';
import 'package:knit/core/ids/uuid_id_generator.dart';
import 'package:knit/core/recents/recents.dart';
import 'package:knit/features/collection/domain/card_share_repository.dart';
import 'package:knit/features/collection/domain/collection_failure.dart';
import 'package:knit/features/collection/domain/collection_models.dart';
import 'package:knit/features/connections/domain/connections_models.dart';
import 'package:knit/features/collection/domain/link_launcher.dart';
import 'package:knit/features/collection/infra/sync_store_card_move_read_repository.dart';
import 'package:knit/features/collection/infra/sync_store_collection_outline_read_repository.dart';
import 'package:knit/features/collection/infra/sync_store_collection_read_repository.dart';
import 'package:knit/features/collection/infra/sync_store_collection_write_repository.dart';
import 'package:knit/features/collection/presentation/collection_action.dart';
import 'package:knit/features/collection/presentation/collection_effect.dart';
import 'package:knit/features/collection/presentation/collection_ui_effect.dart';
import 'package:knit/features/collection/presentation/collection_shell.dart';
import 'package:knit/features/card_links/infra/sync_store_card_links_write_repository.dart';
import 'package:knit/features/card_links/infra/sync_store_link_targets_read_repository.dart';
import 'package:knit/features/card_links/presentation/card_links_controller.dart';
import 'package:knit/features/collection_details/infra/sync_store_collection_details_write_repository.dart';
import 'package:knit/features/collection_details/presentation/collection_details_controller.dart';
import 'package:knit/features/timeline/domain/timeline_channel.dart';
import 'package:knit/features/timeline/infra/sync_store_timeline_write_repository.dart';
import 'package:knit/sync/sync.dart';
import 'package:logging/logging.dart';
import 'package:result_dart/result_dart.dart';

/// Drives the real [CollectionShell] over real in-memory storage for the
/// delete-then-GC path: deleting an image card must reclaim its uniquely-owned
/// attachment record + blob, but a legacy shared record (one record reused by
/// two cards) must survive while a sibling still references it. The ports the
/// delete path never touches are [UnimplementedError] fakes.
class _UnusedShare implements CardShareRepository {
  @override
  Future<Result<void, CollectionFailure>> share(ShareableCard card) =>
      throw UnimplementedError();
}

class _UnusedLinkLauncher implements LinkLauncher {
  @override
  Future<Result<void, CollectionFailure>> open(String url) =>
      throw UnimplementedError();
}

class _FakeTimelineChannel implements TimelineChannelEmitter {
  int emits = 0;
  TimelineChannelEvent? last;
  @override
  void emit(TimelineChannelEvent event) {
    emits++;
    last = event;
  }
}

void main() {
  const ids = UuidIdGenerator();
  late AppGraph graph;
  late SyncStore store;
  late InMemoryAttachmentBlobStore blobs;
  late SyncStoreTimelineWriteRepository timelineWrite;
  late SyncStoreCollectionWriteRepository write;
  late SyncStoreAttachmentWriteRepository attachmentWrite;
  late CollectionShell shell;
  late List<CollectionUiEffect> uiEffects;
  late _FakeTimelineChannel timelineChannel;
  late InMemoryRecentTargetsRepository recents;

  setUp(() async {
    uiEffects = [];
    recents = InMemoryRecentTargetsRepository();
    timelineChannel = _FakeTimelineChannel();
    graph = AppGraph();
    store = SyncStore.inMemory();
    await store.open();
    graph.bindStore(store);
    blobs = InMemoryAttachmentBlobStore();
    graph.bindBlobStore(blobs);
    timelineWrite = SyncStoreTimelineWriteRepository(graph: graph, ids: ids);
    write = SyncStoreCollectionWriteRepository(graph: graph, ids: ids);
    attachmentWrite = SyncStoreAttachmentWriteRepository(
      graph: graph,
      ids: ids,
    );
    shell = CollectionShell(
      readRepository: SyncStoreCollectionReadRepository(graph: graph),
      writeRepository: write,
      moveReadRepository: SyncStoreCardMoveReadRepository(graph: graph),
      recentsReadRepository: recents,
      recentsWriteRepository: recents,
      outlineReadRepository: SyncStoreCollectionOutlineReadRepository(
        graph: graph,
      ),
      attachmentReadRepository: SyncStoreAttachmentReadRepository(graph: graph),
      attachmentWriteRepository: attachmentWrite,
      imageCache: AttachmentImageCache(
        attachmentReadRepository: SyncStoreAttachmentReadRepository(
          graph: graph,
        ),
      ),
      shareRepository: _UnusedShare(),
      linkLauncher: _UnusedLinkLauncher(),
      collectionDetails: CollectionDetailsController(
        writeRepository: SyncStoreCollectionDetailsWriteRepository(
          graph: graph,
        ),
        attachmentWriteRepository: attachmentWrite,
      ),
      cardLinks: CardLinksController(
        readRepository: SyncStoreLinkTargetsReadRepository(graph: graph),
        writeRepository: SyncStoreCardLinksWriteRepository(
          graph: graph,
          ids: ids,
        ),
        recentsReadRepository: recents,
        recentsWriteRepository: recents,
      ),
      effectEmitter: EffectEmitter<CollectionUiEffect>()..attach(uiEffects.add),
      timelineChannel: timelineChannel,
      logger: Logger('test.collection'),
    );
  });

  PickedImage png(List<int> b) =>
      PickedImage(bytes: Uint8List.fromList(b), mime: 'image/png');

  test(
    'deleting a card reclaims its uniquely-owned attachment record + blob',
    () async {
      final colId = (await timelineWrite.createCollection('C')).getOrThrow();
      final attId = (await attachmentWrite.createFromPicked(
        png([1, 2, 3]),
      )).getOrThrow();
      final hash = await sha256Hex(Uint8List.fromList([1, 2, 3]));
      final cardId = (await write.addCard(
        collectionId: colId,
        kind: CardKind.image,
        position: 'a0',
        attachmentId: attId,
      )).getOrThrow();

      await shell.run(
        DeleteCardEffect(cardId, attachmentIds: [attId]),
        dispatch: (_) {},
      );

      expect((await store.get(EntityType.attachment, attId))!.deleted, isTrue);
      expect(await blobs.exists(hash), isFalse);
    },
  );

  test(
    'deleting a card sharing a legacy attachment record keeps the sibling',
    () async {
      final colId = (await timelineWrite.createCollection('C')).getOrThrow();
      final attId = (await attachmentWrite.createFromPicked(
        png([1, 2, 3]),
      )).getOrThrow();
      final hash = await sha256Hex(Uint8List.fromList([1, 2, 3]));
      final cardA = (await write.addCard(
        collectionId: colId,
        kind: CardKind.image,
        position: 'a0',
        attachmentId: attId,
      )).getOrThrow();
      // Sibling card B reuses the SAME record (simulates a pre-fix shared record).
      await write.addCard(
        collectionId: colId,
        kind: CardKind.image,
        position: 'a1',
        attachmentId: attId,
      );

      await shell.run(
        DeleteCardEffect(cardA, attachmentIds: [attId]),
        dispatch: (_) {},
      );

      // The guard skips GC because card B still references it → no orphan.
      expect((await store.get(EntityType.attachment, attId))!.deleted, isFalse);
      expect(await blobs.exists(hash), isTrue);
    },
  );

  test(
    'deleting the collection tells the Timeline and closes the page',
    () async {
      final colId = (await timelineWrite.createCollection('C')).getOrThrow();

      await shell.run(DeleteCollectionEffect(colId), dispatch: (_) {});

      expect((await store.get(EntityType.collection, colId))!.deleted, isTrue);
      final event = timelineChannel.last as CollectionDeletedChannelEvent;
      expect(event.collectionId, colId);
      expect(uiEffects.single, isA<CollectionDeletedUiEffect>());
    },
  );

  test('deleting a text card touches no attachment', () async {
    final colId = (await timelineWrite.createCollection('C')).getOrThrow();
    final cardId = (await write.addCard(
      collectionId: colId,
      kind: CardKind.text,
      position: 'a0',
      text: 'note',
    )).getOrThrow();

    await shell.run(DeleteCardEffect(cardId), dispatch: (_) {});
    expect((await store.get(EntityType.card, cardId))!.deleted, isTrue);
  });

  test(
    'deleting selected cards deletes them all and reclaims attachments',
    () async {
      final colId = (await timelineWrite.createCollection('C')).getOrThrow();
      final attId = (await attachmentWrite.createFromPicked(
        png([4, 5, 6]),
      )).getOrThrow();
      final hash = await sha256Hex(Uint8List.fromList([4, 5, 6]));
      final image = (await write.addCard(
        collectionId: colId,
        kind: CardKind.image,
        position: 'a0',
        attachmentId: attId,
      )).getOrThrow();
      final text = (await write.addCard(
        collectionId: colId,
        kind: CardKind.text,
        position: 'a1',
        text: 'note',
      )).getOrThrow();
      final actions = <CollectionAction>[];

      await shell.run(
        DeleteCardsEffect([image, text], attachmentIds: [attId]),
        dispatch: actions.add,
      );

      expect(actions.single, isA<ReloadRequested>());
      expect((await store.get(EntityType.card, image))!.deleted, isTrue);
      expect((await store.get(EntityType.card, text))!.deleted, isTrue);
      expect((await store.get(EntityType.attachment, attId))!.deleted, isTrue);
      expect(await blobs.exists(hash), isFalse);
    },
  );

  group('move selected cards to another collection', () {
    test(
      'targets list every live collection; the tail is the last card',
      () async {
        final src = (await timelineWrite.createCollection('Src')).getOrThrow();
        final dst = (await timelineWrite.createCollection('Dst')).getOrThrow();
        await write.addCard(
          collectionId: dst,
          kind: CardKind.text,
          position: 'a3',
          text: 'last',
        );

        final actions = <CollectionAction>[];
        await shell.run(const LoadMoveTargetsEffect(), dispatch: actions.add);
        final loaded = actions.single as MoveTargetsLoaded;
        expect(
          loaded.targets.map((t) => t.collectionId),
          containsAll([src, dst]),
        );

        actions.clear();
        final target = MoveTarget(collectionId: dst, title: 'Dst');
        await shell.run(
          LoadMoveTargetTailEffect(target),
          dispatch: actions.add,
        );
        final tail = actions.single as MoveTargetTailLoaded;
        expect(tail.lastPosition, 'a3');
      },
    );

    test('moving writes the cards, refreshes, and reports the move', () async {
      final src = (await timelineWrite.createCollection('Src')).getOrThrow();
      final dst = (await timelineWrite.createCollection('Dst')).getOrThrow();
      final a = (await write.addCard(
        collectionId: src,
        kind: CardKind.text,
        position: 'a0',
        text: 'a',
      )).getOrThrow();
      final b = (await write.addCard(
        collectionId: src,
        kind: CardKind.text,
        position: 'a1',
        text: 'b',
      )).getOrThrow();

      final actions = <CollectionAction>[];
      await shell.run(
        MoveCardsEffect(
          target: MoveTarget(collectionId: dst, title: 'Dst'),
          positions: {a: 'a0', b: 'a1'},
        ),
        dispatch: actions.add,
      );

      expect((await store.feed(dst)).map((s) => s.id), [a, b]);
      expect(await store.feed(src), isEmpty);
      expect(actions.single, isA<ReloadRequested>());
      expect(timelineChannel.emits, 1);
      final moved = uiEffects.single as CollectionCardsMovedUiEffect;
      expect(moved.count, 2);
      expect(moved.targetCollectionId, dst);
      expect(moved.targetTitle, 'Dst');
      // Remembered for the picker's "Recent" row.
      expect((await recents.load(RecentPurpose.move)).getOrThrow().ids, [dst]);
    });

    test('loading targets carries the recently moved-into ids', () async {
      final dst = (await timelineWrite.createCollection('Dst')).getOrThrow();
      await recents.record(RecentPurpose.move, dst);
      final actions = <CollectionAction>[];
      await shell.run(const LoadMoveTargetsEffect(), dispatch: actions.add);
      expect((actions.single as MoveTargetsLoaded).recentIds, [dst]);
    });

    test('a new target is created and delivered with no tail', () async {
      final actions = <CollectionAction>[];
      await shell.run(
        const CreateMoveTargetEffect('Fresh'),
        dispatch: actions.add,
      );
      final tail = actions.single as MoveTargetTailLoaded;
      expect(tail.target.title, 'Fresh');
      expect(tail.lastPosition, isNull);
      final created = await store.get(
        EntityType.collection,
        tail.target.collectionId,
      );
      expect(created?.content['title'], 'Fresh');
      expect(timelineChannel.emits, 1);
    });

    test('a failed move surfaces a message and resyncs', () async {
      final dst = (await timelineWrite.createCollection('Dst')).getOrThrow();
      final actions = <CollectionAction>[];
      await shell.run(
        MoveCardsEffect(
          target: MoveTarget(collectionId: dst, title: 'Dst'),
          positions: const {'missing': 'a0'},
        ),
        dispatch: actions.add,
      );
      expect(actions.single, isA<ReloadRequested>());
      expect(
        (await recents.load(RecentPurpose.move)).getOrThrow().ids,
        isEmpty,
      );
      expect(
        (uiEffects.single as CollectionShowMessageUiEffect).message,
        CollectionMessage.saveFailed,
      );
    });
  });

  test(
    'a Connection card writes card + link, then remembers the target',
    () async {
      final index = (await timelineWrite.createCollection(
        'Index',
      )).getOrThrow();
      final trips = (await timelineWrite.createCollection(
        'Trips',
      )).getOrThrow();
      final actions = <CollectionAction>[];
      await shell.run(
        AddConnectionCardEffect(
          collectionId: index,
          position: 'a0',
          targetKind: ConnectedEntityKind.collection,
          targetId: trips,
        ),
        dispatch: actions.add,
      );

      final card = (await store.feed(index)).single;
      expect(card.content['kind'], 'link');
      expect(card.content['text'], isNull);
      final link = (await store.linksOut(card.id)).single;
      expect(link.content['target_id'], trips);
      expect(actions.single, isA<ReloadRequested>());
      expect(uiEffects, isEmpty);
      // Remembered for the link picker's "Recent" row.
      expect((await recents.load(RecentPurpose.link)).getOrThrow().ids, [
        trips,
      ]);
    },
  );

  test('a Connection card to a card links it, but is no recent', () async {
    final index = (await timelineWrite.createCollection('Index')).getOrThrow();
    const target = 'card-target';
    await shell.run(
      AddConnectionCardEffect(
        collectionId: index,
        position: 'a0',
        targetKind: ConnectedEntityKind.card,
        targetId: target,
      ),
      dispatch: (_) {},
    );

    final card = (await store.feed(index)).single;
    final link = (await store.linksOut(card.id)).single;
    expect(link.content['target_type'], 'card');
    expect(link.content['target_id'], target);
    // The "Recent" row lists collections only.
    expect((await recents.load(RecentPurpose.link)).getOrThrow().ids, isEmpty);
  });

  test(
    'unlinking a Connection card keeps the card, empty, and resyncs',
    () async {
      final index = (await timelineWrite.createCollection(
        'Index',
      )).getOrThrow();
      final trips = (await timelineWrite.createCollection(
        'Trips',
      )).getOrThrow();
      await shell.run(
        AddConnectionCardEffect(
          collectionId: index,
          position: 'a0',
          targetKind: ConnectedEntityKind.collection,
          targetId: trips,
        ),
        dispatch: (_) {},
      );
      final card = (await store.feed(index)).single;
      final link = (await store.linksOut(card.id)).single;

      final actions = <CollectionAction>[];
      await shell.run(UnlinkEffect(link.id), dispatch: actions.add);

      expect(await store.linksOut(card.id), isEmpty);
      expect((await store.feed(index)).single.id, card.id);
      expect(actions.single, isA<ReloadRequested>());
      expect(uiEffects, isEmpty);
    },
  );

  group('quick input', () {
    test('a saved quick card asks the page to close, then resyncs', () async {
      final col = (await timelineWrite.createCollection('Inbox')).getOrThrow();
      final actions = <CollectionAction>[];
      await shell.run(
        AddCardEffect(
          collectionId: col,
          kind: CardKind.link,
          position: 'a0',
          text: 'https://x.y',
          closesQuickInput: true,
        ),
        dispatch: actions.add,
      );
      expect(uiEffects.single, isA<CollectionQuickInputSentUiEffect>());
      expect(actions.single, isA<ReloadRequested>());
    });

    test('an ordinary send leaves the page open', () async {
      final col = (await timelineWrite.createCollection('Inbox')).getOrThrow();
      await shell.run(
        AddCardEffect(
          collectionId: col,
          kind: CardKind.text,
          position: 'a0',
          text: 'hi',
        ),
        dispatch: (_) {},
      );
      expect(uiEffects, isEmpty);
    });
  });

  test(
    'settling writes the cards, refreshes, and reads back settled',
    () async {
      final col = (await timelineWrite.createCollection('Steps')).getOrThrow();
      final a = (await write.addCard(
        collectionId: col,
        kind: CardKind.text,
        position: 'a0',
        text: 'a',
      )).getOrThrow();

      final actions = <CollectionAction>[];
      await shell.run(
        SettleCardsEffect([a], settled: true),
        dispatch: actions.add,
      );

      expect(actions.single, isA<ReloadRequested>());
      expect(timelineChannel.emits, 1);
      final data = (await SyncStoreCollectionReadRepository(
        graph: graph,
      ).loadCollection(col)).getOrThrow();
      expect(data.cards.single.settled, isTrue);

      actions.clear();
      await shell.run(
        SettleCardsEffect([a], settled: false),
        dispatch: actions.add,
      );
      final after = (await SyncStoreCollectionReadRepository(
        graph: graph,
      ).loadCollection(col)).getOrThrow();
      expect(after.cards.single.settled, isFalse);
    },
  );

  test('emphasizing writes the cards and clears their settle', () async {
    final col = (await timelineWrite.createCollection('Steps')).getOrThrow();
    final a = (await write.addCard(
      collectionId: col,
      kind: CardKind.text,
      position: 'a0',
      text: 'a',
    )).getOrThrow();
    await shell.run(SettleCardsEffect([a], settled: true), dispatch: (_) {});

    final actions = <CollectionAction>[];
    await shell.run(
      EmphasizeCardsEffect([a], emphasized: true),
      dispatch: actions.add,
    );

    expect(actions.single, isA<ReloadRequested>());
    final data = (await SyncStoreCollectionReadRepository(
      graph: graph,
    ).loadCollection(col)).getOrThrow();
    expect(data.cards.single.emphasized, isTrue);
    expect(data.cards.single.settled, isFalse);
  });

  test('the outline read delivers the whole feed, older pages too', () async {
    final col = (await timelineWrite.createCollection('Long')).getOrThrow();
    final ids = <String>[];
    var position = 'a0';
    for (var i = 0; i < 3; i++) {
      ids.add(
        (await write.addCard(
          collectionId: col,
          kind: CardKind.text,
          position: position,
          text: 'card $i',
        )).getOrThrow(),
      );
      position = 'a${i + 1}';
    }
    await write.setCardsEmphasized([ids[0]], emphasized: true);

    final actions = <CollectionAction>[];
    await shell.run(LoadOutlineEffect(col), dispatch: actions.add);

    final cards = (actions.single as OutlineCardsLoaded).cards;
    expect(cards.map((c) => c.id), ids);
    expect(cards.first.emphasized, isTrue);
  });
}
