import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:knit/core/files/files.dart';
import 'package:knit/features/collection_share/domain/domain.dart';
import 'package:knit/features/collection_share/infra/infra.dart';
import 'package:knit/features/collection_share/presentation/collection_share_export_controller.dart';
import 'package:knit/features/collection_share/presentation/collection_share_export_state.dart';
import 'package:knit/sync/sync.dart';
import 'package:logging/logging.dart';
import 'package:result_dart/result_dart.dart';

import 'share_fixture.dart';

class _FailingSavePort implements FileSavePort {
  @override
  Future<Result<bool, FileFailure>> save(OutgoingFile file) async =>
      Failure(FileSaveFailure(StateError('disk full')));
}

void main() {
  late SyncStoreCollectionShareExportRepository repository;

  setUp(() async {
    final sender = await device('mira');
    await seedTrip(sender);
    await sender.edit(EntityType.collection, 'trip', {
      'title': 'Trip: Kyoto/Osaka',
    });
    final graph = graphOf(sender);
    await graph.blobStore.put('h-1', Uint8List.fromList([7, 8, 9]));
    repository = SyncStoreCollectionShareExportRepository(
      graph: graph,
      now: () => DateTime.fromMillisecondsSinceEpoch(4242),
    );
  });

  group('SyncStoreCollectionShareExportRepository', () {
    test('estimate counts live cards and media', () async {
      final estimate = (await repository.estimate('trip')).getOrThrow();
      expect(estimate.title, 'Trip: Kyoto/Osaka');
      expect(estimate.cardCount, 3);
      expect(estimate.mediaCount, 1);
      expect(estimate.mediaBytes, 3);
      expect(estimate.sizeWith(media: true), estimate.baseBytes + 3);
    });

    test('export with media round-trips through the codec', () async {
      final file = (await repository.export(
        'trip',
        includeMedia: true,
      )).getOrThrow();
      expect(file.fileName, 'Trip  Kyoto Osaka.knitc');
      expect(file.mimeType, kCollectionShareMime);

      final bundle = const CollectionShareCodec().decode(file.bytes);
      expect(bundle.manifest.collectionId, 'trip');
      expect(bundle.manifest.createdAtMs, 4242);
      expect(bundle.manifest.mediaIncluded, isTrue);
      expect(bundle.manifest.cardCount, 3);
      expect(bundle.manifest.opCount, bundle.ops.length);
      expect(bundle.blobs['h-1'], [7, 8, 9]);
    });

    test('export without media ships no blobs', () async {
      final file = (await repository.export(
        'trip',
        includeMedia: false,
      )).getOrThrow();
      final bundle = const CollectionShareCodec().decode(file.bytes);
      expect(bundle.manifest.mediaIncluded, isFalse);
      expect(bundle.blobs, isEmpty);
    });

    test('an unknown collection fails', () async {
      expect(
        (await repository.export('nope', includeMedia: true)).error,
        isA<CollectionShareExportFailure>(),
      );
    });
  });

  group('CollectionShareExportController', () {
    late RecordingFileDeliveryPort delivery;
    late RecordingFileSavePort save;
    CollectionShareExportController controller({FileSavePort? savePort}) =>
        CollectionShareExportController(
          collectionId: 'trip',
          exportRepository: repository,
          deliveryPort: delivery,
          savePort: savePort ?? save,
          logger: Logger('test'),
        );

    setUp(() {
      delivery = RecordingFileDeliveryPort();
      save = RecordingFileSavePort();
    });

    test('loads the estimate, media on by default', () async {
      final c = controller();
      await c.load();
      expect(c.state.status, ShareExportStatus.ready);
      expect(c.state.includeMedia, isTrue);
      expect(c.state.hasMedia, isTrue);
      expect(c.state.size, c.state.estimate!.sizeWith(media: true));
      c.setIncludeMedia(false);
      expect(c.state.size, c.state.estimate!.baseBytes);
    });

    test('send hands the file to the share sheet', () async {
      final c = controller();
      await c.load();
      c.setIncludeMedia(false);
      expect(
        await c.deliver(ShareExportDestination.send),
        ShareExportOutcome.sent,
      );
      final bundle = const CollectionShareCodec().decode(
        delivery.lastShared!.bytes,
      );
      expect(bundle.manifest.mediaIncluded, isFalse);
    });

    test('save reports saved, cancelled and failed', () async {
      final c = controller();
      await c.load();
      expect(
        await c.deliver(ShareExportDestination.save),
        ShareExportOutcome.saved,
      );
      save.saved = false;
      expect(
        await c.deliver(ShareExportDestination.save),
        ShareExportOutcome.cancelled,
      );
      expect(c.state.failed, isFalse);

      final failing = controller(savePort: _FailingSavePort());
      await failing.load();
      expect(
        await failing.deliver(ShareExportDestination.save),
        ShareExportOutcome.failed,
      );
      expect(failing.state.failed, isTrue);
      expect(failing.state.busy, isFalse);
    });
  });
}
