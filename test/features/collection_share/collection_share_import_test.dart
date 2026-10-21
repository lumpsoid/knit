import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:knit/app/app_graph.dart';
import 'package:knit/core/attachments/attachments.dart';
import 'package:knit/core/files/files.dart';
import 'package:knit/features/collection/presentation/collection_route_args.dart';
import 'package:knit/features/collection_share/domain/domain.dart';
import 'package:knit/features/collection_share/infra/infra.dart';
import 'package:knit/features/collection_share/presentation/collection_share_import_controller.dart';
import 'package:knit/features/collection_share/presentation/collection_share_import_state.dart';
import 'package:knit/features/timeline/domain/timeline_channel.dart';
import 'package:knit/sync/sync.dart';
import 'package:logging/logging.dart';

import 'share_fixture.dart';

class _RecordingChannel implements TimelineChannelEmitter {
  final events = <TimelineChannelEvent>[];
  @override
  void emit(TimelineChannelEvent event) => events.add(event);
}

void main() {
  late SyncStore sender;
  late AppGraph senderGraph;
  late SyncStore recipient;
  late AppGraph recipientGraph;
  late SyncStoreCollectionShareImportRepository importer;

  Future<Uint8List> exportFile({bool media = true}) async =>
      (await SyncStoreCollectionShareExportRepository(
        graph: senderGraph,
      ).export('trip', includeMedia: media)).getOrThrow().bytes;

  final imageBytes = Uint8List.fromList([1, 2, 3]);
  late String imageHash;

  setUp(() async {
    imageHash = await sha256Hex(imageBytes);
    sender = await device('mira');
    await seedTrip(sender, imageHash: imageHash);
    senderGraph = graphOf(sender);
    await senderGraph.blobStore.put(imageHash, imageBytes);
    recipient = await device('kai');
    await recipient.create(EntityType.profile, await recipient.authorPubkey(), {
      'nickname': 'kai',
    });
    recipientGraph = graphOf(recipient);
    importer = SyncStoreCollectionShareImportRepository(graph: recipientGraph);
  });

  group('SyncStoreCollectionShareImportRepository', () {
    test('plans a preview from the verified ops, then imports', () async {
      final plan = (await importer.plan(await exportFile())).getOrThrow();
      expect(plan.title, 'Trip to Kyoto');
      expect(plan.cardCount, 3);
      expect(plan.ownerNickname, 'mira');
      expect(
        plan.ownerFingerprint,
        await recipient.signer.fingerprintOf(await sender.authorPubkey()),
      );
      expect(plan.isUpdate, isFalse);
      expect(plan.isOwn, isFalse);
      expect(plan.mediaIncluded, isTrue);

      final pendingBefore = await recipient.pendingCount();
      final result = (await importer.apply(plan)).getOrThrow();
      expect(result.collectionId, 'trip');
      expect(result.blobsRestored, 1);
      expect((await recipient.feed('trip')).map((c) => c.id), [
        'c1',
        'c2',
        'c3',
      ]);
      expect(await recipientGraph.blobStore.readBytes(imageHash), [1, 2, 3]);
      expect(await recipient.pendingCount(), pendingBefore);
    });

    test(
      'a newer file updates the copy; an older one changes nothing',
      () async {
        final older = await exportFile(media: false);
        await importer.apply((await importer.plan(older)).getOrThrow());

        await sender.edit(EntityType.card, 'c1', {'text': 'c1 v2'});
        final newer = await exportFile(media: false);
        final update = (await importer.plan(newer)).getOrThrow();
        expect(update.isUpdate, isTrue);
        await importer.apply(update);
        expect(
          (await recipient.get(EntityType.card, 'c1'))!.content['text'],
          'c1 v2',
        );

        await importer.apply((await importer.plan(older)).getOrThrow());
        expect(
          (await recipient.get(EntityType.card, 'c1'))!.content['text'],
          'c1 v2',
        );
      },
    );

    test(
      'a file without media leaves the blob out until one brings it',
      () async {
        await importer.apply(
          (await importer.plan(await exportFile(media: false))).getOrThrow(),
        );
        expect(await recipientGraph.blobStore.exists(imageHash), isFalse);
        await importer.apply(
          (await importer.plan(await exportFile())).getOrThrow(),
        );
        expect(await recipientGraph.blobStore.exists(imageHash), isTrue);
      },
    );

    test('your own file is a mini-restore', () async {
      final own = SyncStoreCollectionShareImportRepository(graph: senderGraph);
      final plan = (await own.plan(await exportFile())).getOrThrow();
      expect(plan.isOwn, isTrue);
      expect(plan.isUpdate, isTrue);
      final result = (await own.apply(plan)).getOrThrow();
      expect(result.opsApplied, 0);
    });

    test('a file targeting the recipient\'s own ids is refused', () async {
      // Kai already has a card with id c1 (his own).
      await recipient.create(EntityType.collection, 'kai-col', {'title': 'K'});
      await recipient.create(EntityType.card, 'c1', {
        'collection_id': 'kai-col',
        'kind': 'text',
        'text': 'mine',
      }, position: 'a0');
      final failure = (await importer.plan(await exportFile())).error;
      expect(failure, isA<CollectionShareRejectedFailure>());
      expect(
        (failure! as CollectionShareRejectedFailure).reason,
        ShareRejection.foreignOverwrite,
      );
      expect(
        (await recipient.get(EntityType.card, 'c1'))!.content['text'],
        'mine',
      );
    });

    test('a tampered payload fails its signature', () async {
      final bundle = const CollectionShareCodec().decode(await exportFile());
      final forged = [
        for (final op in bundle.ops)
          op.entityId == 'c2'
              ? PersistedOp.fromDb({
                  ...op.toDb(),
                  'payload': op.payload.replaceFirst(
                    '"text":"c2"',
                    '"text":"forged"',
                  ),
                })
              : op,
      ];
      final bytes = const CollectionShareCodec().encode(
        CollectionShareBundle(
          manifest: bundle.manifest,
          ops: forged,
          blobs: const {},
        ),
      );
      final failure = (await importer.plan(bytes)).error;
      expect(
        (failure! as CollectionShareRejectedFailure).reason,
        ShareRejection.badSignature,
      );
    });

    test('junk is corrupt', () async {
      expect(
        (await importer.plan(Uint8List.fromList([1, 2, 3]))).error,
        isA<CollectionShareCorruptFailure>(),
      );
    });

    test('a blob whose bytes do not match its hash is skipped', () async {
      final bundle = const CollectionShareCodec().decode(await exportFile());
      final bytes = const CollectionShareCodec().encode(
        CollectionShareBundle(
          manifest: bundle.manifest,
          ops: bundle.ops,
          blobs: {
            imageHash: Uint8List.fromList([9]),
          },
        ),
      );
      final result = (await importer.apply(
        (await importer.plan(bytes)).getOrThrow(),
      )).getOrThrow();
      expect(result.blobsRestored, 0);
      expect(await recipientGraph.blobStore.exists(imageHash), isFalse);
    });
  });

  group('CollectionShareImportController', () {
    late StubFileSourcePort source;
    late InMemoryCollectionRouteArgsStore routeArgs;
    late _RecordingChannel channel;
    CollectionShareImportController controller() =>
        CollectionShareImportController(
          importRepository: importer,
          sourcePort: source,
          collectionRouteArgs: routeArgs,
          timelineChannel: channel,
          readFile: (path) async => path == 'trip.knitc'
              ? exportFile()
              : throw StateError('no such file'),
          logger: Logger('test'),
        );

    setUp(() {
      source = StubFileSourcePort();
      routeArgs = InMemoryCollectionRouteArgsStore();
      channel = _RecordingChannel();
    });

    test('a cancelled pick previews nothing', () async {
      final c = controller();
      expect(await c.pick(), isFalse);
      expect(source.lastExtensions, isNull, reason: 'any file can be picked');
    });

    test('pick → preview → confirm opens the collection', () async {
      source.bytes = await exportFile();
      final c = controller();
      expect(await c.pick(), isTrue);
      expect(c.state.status, ShareImportStatus.ready);
      expect(c.state.plan!.title, 'Trip to Kyoto');

      expect(await c.confirm(), 'trip');
      expect(routeArgs.collectionId, 'trip');
      expect(channel.events.single, isA<RefreshChannelEvent>());
      expect(await recipient.get(EntityType.collection, 'trip'), isNotNull);
    });

    test('an opened file is read from its path', () async {
      final c = controller();
      await c.open('trip.knitc');
      expect(c.state.status, ShareImportStatus.ready);

      final missing = controller();
      await missing.open('gone.knitc');
      expect(missing.state.status, ShareImportStatus.failed);
      expect(missing.state.problem, ShareImportProblem.unreadable);
    });

    test('a refused file says so and cannot be confirmed', () async {
      await recipient.create(EntityType.collection, 'trip', {'title': 'Mine'});
      source.bytes = await exportFile();
      final c = controller();
      await c.pick();
      expect(c.state.problem, ShareImportProblem.refused);
      expect(await c.confirm(), isNull);
      expect(channel.events, isEmpty);
    });
  });

  test('CollectionShareFiles.matches by mime or .knitc name', () {
    expect(
      CollectionShareFiles.matches(name: 'x.bin', mime: kCollectionShareMime),
      isTrue,
    );
    expect(
      CollectionShareFiles.matches(
        name: 'Trip.KNITC',
        mime: 'application/octet-stream',
      ),
      isTrue,
    );
    expect(
      CollectionShareFiles.matches(name: 'photo.jpg', mime: 'image/jpeg'),
      isFalse,
    );
  });
}
