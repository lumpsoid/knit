import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:knit/app/app_graph.dart';
import 'package:knit/core/files/files.dart';
import 'package:knit/features/collection/presentation/collection_route_args.dart';
import 'package:knit/features/collection_share/domain/domain.dart';
import 'package:knit/features/collection_share/infra/infra.dart';
import 'package:knit/features/collection_share/presentation/collection_share_export_controller.dart';
import 'package:knit/features/collection_share/presentation/collection_share_import_controller.dart';
import 'package:knit/features/timeline/domain/timeline_channel.dart';
import 'package:knit/sync/sync.dart';
import 'package:logging/logging.dart';

import 'share_fixture.dart';

class _NullChannel implements TimelineChannelEmitter {
  @override
  void emit(TimelineChannelEvent event) {}
}

/// Sharing an index (docs/collection_share.md "Linked collections"): the
/// outside-links rule, the one-level own-only bundle, the version-2 manifest
/// and its compatibility, and the whole-file validation and import.
void main() {
  const codec = CollectionShareCodec();
  const policy = CollectionShareImportPolicy();

  late SyncStore sender;
  late AppGraph senderGraph;

  setUp(() async {
    // Kai's own collection, imported by Mira: she may link to it, but never
    // bundle it.
    final kai = await device('kai');
    await kai.create(EntityType.profile, await kai.authorPubkey(), {
      'nickname': 'kai',
    }, physicalNowMs: 1000);
    await kai.create(EntityType.collection, 'kai-col', {
      'title': 'Kai',
    }, physicalNowMs: 1000);

    sender = await device('mira');
    await seedTrip(sender);
    for (final op in (await kai.shareSet('kai-col')).ops) {
      await sender.applyRemote(op, 2000);
    }
    await seedIndex(sender, foreignId: 'kai-col');
    senderGraph = graphOf(sender);
    await senderGraph.blobStore.put('h-1', Uint8List.fromList([7, 8, 9]));
  });

  group('ShareReach', () {
    Future<ShareReach> reachOf(String id) async {
      final rows = await sender.projection.readAll();
      return ShareReach.of(
        ShareScope.of(id, rows),
        rows,
        me: await sender.authorPubkey(),
      );
    }

    test('counts live outside links once per pair', () async {
      final reach = await reachOf('index');
      // i1→trip (two links, one pair), i2→n1, index→gone, index→kai-col;
      // the deleted card i3's link to far does not count.
      expect(reach.outsideCount, 4);
      expect(reach.notOwnedCount, 1, reason: 'kai-col is not Mira\'s');
      expect(reach.linkedCollectionIds, [
        'trip',
        'notes',
      ], reason: 'a card target brings its collection; gone is missing');
    });

    test('links inside the collection are not outside', () async {
      final reach = await reachOf('trip');
      expect(reach.outsideCount, 0);
      expect(reach.linkedCollectionIds, isEmpty);
    });

    test('without an identity nothing is own', () async {
      final rows = await sender.projection.readAll();
      final reach = ShareReach.of(ShareScope.of('index', rows), rows, me: null);
      expect(reach.notOwnedCount, 3);
      expect(reach.linkedCollectionIds, isEmpty);
    });
  });

  group('shareSet with linked collections', () {
    Set<String> idsOf(ShareSet set) => {for (final op in set.ops) op.entityId};

    test('off: only the collection itself', () async {
      final set = await sender.shareSet('index');
      expect(set.included, isEmpty);
      expect(set.reach.outsideCount, 4);
      expect(idsOf(set).intersection({'trip', 'c1', 'notes', 'n1'}), isEmpty);
      expect(set.media, isEmpty);
    });

    test('on: each own linked collection whole, one level deep', () async {
      final set = await sender.shareSet('index', includeLinked: true);
      expect(set.included.map((i) => i.collection.id), ['trip', 'notes']);
      expect(set.included.first.liveCardCount, 3);
      final ids = idsOf(set);
      expect(
        ids,
        containsAll(['index', 'i1', 'trip', 'c1', 'c4', 'l1', 'att-1']),
      );
      expect(ids, containsAll(['notes', 'n1', 'ln']));
      expect(
        ids.intersection({'far', 'kai-col', 'gone'}),
        isEmpty,
        reason: 'not followed further, not own, missing',
      );
      expect(set.media.keys, ['h-1']);
      expect(
        set.ops.map((op) => op.opId).toSet(),
        hasLength(set.ops.length),
        reason: 'an op ships once',
      );
    });
  });

  group('codec and manifest', () {
    test('a linked file is version 2 and round-trips its entries', () async {
      final bundle = await bundleOf(
        sender,
        collectionId: 'index',
        includeLinked: true,
      );
      expect(bundle.manifest.version, kCollectionShareVersion);
      final decoded = codec.decode(codec.encode(bundle));
      expect(decoded.manifest.toJson(), bundle.manifest.toJson());
      expect(decoded.manifest.included.map((e) => e.collectionId), [
        'trip',
        'notes',
      ]);
      expect(decoded.manifest.included.first.title, 'Trip to Kyoto');
      expect(decoded.ops.length, bundle.ops.length);
    });

    test('a single-collection file stays version 1, as before', () async {
      final bundle = await bundleOf(sender, collectionId: 'index');
      expect(bundle.manifest.version, kCollectionShareSingleVersion);
      expect(bundle.manifest.toJson().containsKey('included'), isFalse);
    });

    test('an old version-1 file still imports unchanged', () async {
      final set = await sender.shareSet('trip');
      // Exactly what the first `.knitc` release wrote.
      final bytes = LogArchive.encode(
        LogArchiveEntries(
          manifest: {
            'format': 'knit-collection',
            'version': 1,
            'createdAtMs': 2000,
            'collectionId': 'trip',
            'owner': await sender.authorPubkey(),
            'title': 'Trip to Kyoto',
            'cardCount': 3,
            'opCount': set.ops.length,
            'blobCount': 0,
            'mediaIncluded': false,
          },
          opLines: [for (final op in set.ops) jsonEncode(op.toDb())],
          blobs: const {},
        ),
      );
      final decoded = codec.decode(bytes);
      expect(decoded.manifest.version, 1);
      expect(decoded.manifest.included, isEmpty);

      final recipient = await device('zoe');
      final importer = SyncStoreCollectionShareImportRepository(
        graph: graphOf(recipient),
      );
      final plan = (await importer.plan(bytes)).getOrThrow();
      expect(plan.linkedCollectionCount, 0);
      await importer.apply(plan);
      expect((await recipient.feed('trip')).map((c) => c.id), [
        'c1',
        'c2',
        'c3',
      ]);
    });
  });

  group('CollectionShareImportPolicy over linked collections', () {
    ShareRejection? check(
      CollectionShareBundle bundle, {
      Set<String> badSignatures = const {},
      Map<String, String> localCreatedBy = const {},
    }) => policy.check(
      bundle,
      badSignatures: badSignatures,
      localCreatedBy: localCreatedBy,
    );

    Future<CollectionShareBundle> linked() =>
        bundleOf(sender, collectionId: 'index', includeLinked: true);

    CollectionShareBundle withEntries(
      CollectionShareBundle bundle,
      List<CollectionShareEntry> included,
    ) => CollectionShareBundle(
      manifest: CollectionShareManifest(
        createdAtMs: bundle.manifest.createdAtMs,
        collectionId: bundle.manifest.collectionId,
        owner: bundle.manifest.owner,
        title: bundle.manifest.title,
        cardCount: bundle.manifest.cardCount,
        opCount: bundle.manifest.opCount,
        blobCount: bundle.manifest.blobCount,
        mediaIncluded: bundle.manifest.mediaIncluded,
        included: included,
      ),
      ops: bundle.ops,
      blobs: bundle.blobs,
    );

    test('accepts every declared collection', () async {
      expect(check(await linked()), isNull);
    });

    test('a bad signature in a linked collection refuses the file', () async {
      final bundle = await linked();
      final n1 = bundle.ops.firstWhere((op) => op.entityId == 'n1');
      expect(
        check(bundle, badSignatures: {n1.opId}),
        ShareRejection.badSignature,
      );
    });

    test('a linked collection\'s ops outside the declared ones', () async {
      final bundle = await linked();
      final trip = bundle.manifest.included.first;
      expect(trip.collectionId, 'trip');
      // `notes` ops ship, but only `trip` is declared.
      expect(
        check(withEntries(bundle, [trip])),
        ShareRejection.outsideCollection,
      );
      // A declared collection with no collection op in the file.
      expect(
        check(
          withEntries(bundle, [
            ...bundle.manifest.included,
            CollectionShareEntry(
              collectionId: 'far',
              owner: trip.owner,
              title: 'far',
              cardCount: 0,
            ),
          ]),
        ),
        ShareRejection.outsideCollection,
      );
    });

    test('a linked collection is held to its own owner', () async {
      final bundle = await linked();
      final [trip, notes] = bundle.manifest.included;
      expect(
        check(
          withEntries(bundle, [
            trip,
            CollectionShareEntry(
              collectionId: notes.collectionId,
              owner: 'kai-pubkey',
              title: notes.title,
              cardCount: notes.cardCount,
            ),
          ]),
        ),
        ShareRejection.foreignAuthor,
      );
    });

    test('a collection declared twice is malformed', () async {
      final bundle = await linked();
      final trip = bundle.manifest.included.first;
      expect(
        check(withEntries(bundle, [trip, trip])),
        ShareRejection.malformed,
      );
    });

    test('the foreign-overwrite rule covers linked collections', () async {
      expect(
        check(await linked(), localCreatedBy: {'n1': 'zoe-pubkey'}),
        ShareRejection.foreignOverwrite,
      );
    });
  });

  group('importing an index', () {
    late SyncStore recipient;
    late SyncStoreCollectionShareImportRepository importer;

    Future<Uint8List> exportIndex({bool linked = true}) async =>
        (await SyncStoreCollectionShareExportRepository(
              graph: senderGraph,
            ).export('index', includeMedia: true, includeLinked: linked))
            .getOrThrow()
            .bytes;

    setUp(() async {
      recipient = await device('zoe');
      importer = SyncStoreCollectionShareImportRepository(
        graph: graphOf(recipient),
      );
    });

    test(
      'applies every collection, read-only, and opens the primary',
      () async {
        final routeArgs = InMemoryCollectionRouteArgsStore();
        final source = StubFileSourcePort()..bytes = await exportIndex();
        final controller = CollectionShareImportController(
          importRepository: importer,
          sourcePort: source,
          collectionRouteArgs: routeArgs,
          timelineChannel: _NullChannel(),
          logger: Logger('test'),
        );
        expect(await controller.pick(), isTrue);
        final plan = controller.state.plan!;
        expect(plan.title, 'index');
        expect(plan.linkedCollectionCount, 2);

        expect(await controller.confirm(), 'index');
        expect(routeArgs.collectionId, 'index');
        final mira = await sender.authorPubkey();
        for (final id in ['index', 'trip', 'notes']) {
          expect(
            (await recipient.get(EntityType.collection, id))!.createdBy,
            mira,
            reason: id,
          );
        }
        expect((await recipient.feed('notes')).map((c) => c.id), ['n1']);
        expect(await recipient.get(EntityType.collection, 'far'), isNull);
        expect(await recipient.get(EntityType.collection, 'kai-col'), isNull);
        // Each one is removed on its own.
        await recipient.purgeCollection('trip');
        expect(await recipient.get(EntityType.collection, 'trip'), isNull);
        expect(await recipient.get(EntityType.collection, 'notes'), isNotNull);
      },
    );

    test('a linked collection the recipient owns refuses the file', () async {
      await recipient.create(EntityType.collection, 'notes', {'title': 'N'});
      final failure = (await importer.plan(await exportIndex())).error;
      expect(
        (failure! as CollectionShareRejectedFailure).reason,
        ShareRejection.foreignOverwrite,
      );
    });

    test('the author\'s own linked file merges as a mini-restore', () async {
      final own = SyncStoreCollectionShareImportRepository(graph: senderGraph);
      final plan = (await own.plan(await exportIndex())).getOrThrow();
      expect(plan.isOwn, isTrue);
      expect((await own.apply(plan)).getOrThrow().opsApplied, 0);
    });
  });

  group('CollectionShareExportController and the linked switch', () {
    late RecordingFileDeliveryPort delivery;
    late CollectionShareExportController controller;

    setUp(() async {
      delivery = RecordingFileDeliveryPort();
      controller = CollectionShareExportController(
        collectionId: 'index',
        exportRepository: SyncStoreCollectionShareExportRepository(
          graph: senderGraph,
        ),
        deliveryPort: delivery,
        savePort: RecordingFileSavePort(),
        logger: Logger('test'),
      );
      await controller.load();
    });

    test('warns about outside links; the switch starts off', () {
      final state = controller.state;
      expect(state.outsideCount, 4);
      expect(state.notOwnedCount, 1);
      expect(state.linkedCollectionCount, 2);
      expect(state.includeLinked, isFalse);
      expect(state.hasMedia, isFalse, reason: 'the index has no media');
    });

    test('the size estimate follows the switch', () async {
      final state = controller.state;
      final alone = state.size!;
      controller.setIncludeLinked(true);
      expect(state.hasMedia, isTrue, reason: 'trip brings its image');
      expect(state.size, state.estimate!.withLinked.sizeWith(media: true));
      expect(state.size, greaterThan(alone));
      controller.setIncludeMedia(false);
      expect(state.size, state.estimate!.withLinked.baseBytes);
      controller.setIncludeLinked(false);
      expect(state.size, alone);

      controller
        ..setIncludeLinked(true)
        ..setIncludeMedia(true);
      expect(
        await controller.deliver(ShareExportDestination.send),
        ShareExportOutcome.sent,
      );
      final bundle = codec.decode(delivery.lastShared!.bytes);
      expect(bundle.manifest.included, hasLength(2));
      expect(bundle.blobs['h-1'], [7, 8, 9]);
    });

    test('a collection without outside links shows neither', () async {
      final trip = CollectionShareExportController(
        collectionId: 'trip',
        exportRepository: SyncStoreCollectionShareExportRepository(
          graph: senderGraph,
        ),
        deliveryPort: delivery,
        savePort: RecordingFileSavePort(),
        logger: Logger('test'),
      );
      await trip.load();
      expect(trip.state.outsideCount, 0);
      expect(trip.state.linkedCollectionCount, 0);
      trip.setIncludeLinked(true);
      expect(trip.state.linked, isFalse);
      expect(trip.state.size, trip.state.estimate!.alone.sizeWith(media: true));
    });
  });
}
