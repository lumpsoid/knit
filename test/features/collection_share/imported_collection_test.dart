import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:knit/app/app_graph.dart';
import 'package:knit/core/attachments/attachments.dart';
import 'package:knit/core/ids/uuid_id_generator.dart';
import 'package:knit/features/collection/presentation/collection_route_args.dart';
import 'package:knit/features/collection_share/infra/infra.dart';
import 'package:knit/features/collection_share/presentation/imported_collection_controller.dart';
import 'package:knit/features/timeline/domain/timeline_channel.dart';
import 'package:knit/sync/sync.dart';
import 'package:logging/logging.dart';

import 'share_fixture.dart';

class _RecordingChannel implements TimelineChannelEmitter {
  final events = <TimelineChannelEvent>[];
  @override
  void emit(TimelineChannelEvent event) => events.add(event);
}

/// Save a copy (§10.5 fork) and Remove (local purge) of an imported
/// collection (docs/collection_share.md).
void main() {
  late SyncStore recipient;
  late AppGraph graph;
  late String imageHash;
  late InMemoryCollectionRouteArgsStore routeArgs;
  late _RecordingChannel channel;
  late InMemoryLocalArchiveRepository localArchive;
  late ImportedCollectionController controller;

  setUp(() async {
    final bytes = Uint8List.fromList([1, 2, 3]);
    imageHash = await sha256Hex(bytes);
    final sender = await device('mira');
    await seedTrip(sender, imageHash: imageHash);
    recipient = await device('kai');
    graph = graphOf(recipient);
    for (final op in (await sender.shareSet('trip')).ops) {
      await recipient.applyRemote(op, 5000);
    }
    await graph.blobStore.put(imageHash, bytes);
    routeArgs = InMemoryCollectionRouteArgsStore();
    channel = _RecordingChannel();
    localArchive = InMemoryLocalArchiveRepository({'trip'});
    controller = ImportedCollectionController(
      forkRepository: SyncStoreCollectionForkRepository(
        graph: graph,
        ids: const UuidIdGenerator(),
      ),
      purgeRepository: SyncStoreCollectionPurgeRepository(graph: graph),
      localArchive: localArchive,
      collectionRouteArgs: routeArgs,
      timelineChannel: channel,
      logger: Logger('test'),
    );
  });

  test('Save a copy forks the live set as the user\'s own', () async {
    final me = await recipient.authorPubkey();
    final copyId = await controller.saveCopy('trip');

    expect(copyId, isNotNull);
    expect(routeArgs.collectionId, copyId);
    expect(channel.events.single, isA<RefreshChannelEvent>());

    final copy = (await recipient.get(EntityType.collection, copyId!))!;
    expect(copy.createdBy, me);
    expect(copy.content['title'], 'Trip to Kyoto');
    final cards = await recipient.feed(copyId);
    expect(cards.map((c) => c.content['text']), ['c1', 'c2', 'c3']);
    expect(cards.every((c) => c.createdBy == me), isTrue);
    expect(
      cards.map((c) => c.id).toSet().intersection({'c1', 'c2', 'c3'}),
      isEmpty,
    );

    // The image card points at a new attachment over the same bytes.
    final image = cards.last;
    final attachment = (await recipient.get(
      EntityType.attachment,
      image.content['attachment_id']! as String,
    ))!;
    expect(attachment.id, isNot('att-1'));
    expect(attachment.content['content_hash'], imageHash);

    // The intra-set link c1 → c2 is rewritten onto the copies.
    final links = await recipient.linksOut(cards.first.id);
    expect(links.single.content['target_id'], cards[1].id);

    // The source stays.
    expect((await recipient.feed('trip')), hasLength(3));
  });

  test(
    'Remove purges the collection, its blobs and its archive flag',
    () async {
      expect(await controller.remove('trip'), isTrue);
      expect(await recipient.get(EntityType.collection, 'trip'), isNull);
      expect(await recipient.feed('trip'), isEmpty);
      expect(await graph.blobStore.exists(imageHash), isFalse);
      expect((await localArchive.loadArchived()).getOrThrow(), isEmpty);
      expect(
        (channel.events.single as CollectionDeletedChannelEvent).collectionId,
        'trip',
      );
    },
  );

  test('a copy keeps the shared blob alive after Remove', () async {
    await controller.saveCopy('trip');
    expect(await controller.remove('trip'), isTrue);
    expect(await graph.blobStore.exists(imageHash), isTrue);
  });

  test('Remove refuses an own collection', () async {
    final copyId = await controller.saveCopy('trip');
    expect(await controller.remove(copyId!), isFalse);
    expect(controller.state.failed, isTrue);
    expect(await recipient.get(EntityType.collection, copyId), isNotNull);
  });
}
