import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:knit/app/app_graph.dart';
import 'package:knit/core/attachments/attachments.dart';
import 'package:knit/features/backup/domain/backup_failure.dart';
import 'package:knit/features/backup/infra/backup_archive_codec.dart';
import 'package:knit/features/backup/infra/sync_store_backup_export_repository.dart';
import 'package:knit/features/backup/infra/sync_store_backup_import_repository.dart';
import 'package:knit/sync/sync.dart';

void main() {
  const colId = 'col-1';
  const cardId = 'card-1';
  const attId = 'att-1';
  final blobBytes = Uint8List.fromList([10, 20, 30, 40, 50]);

  /// A fresh in-memory graph (store + blob store), with identity provisioned.
  Future<AppGraph> emptyGraph() async {
    final graph = AppGraph()
      ..bindStore(SyncStore.inMemory())
      ..bindBlobStore(InMemoryAttachmentBlobStore());
    await graph.store.open();
    return graph;
  }

  /// Seed a graph with one collection, one card, and one image attachment whose
  /// bytes live in the blob store under their real content hash.
  Future<AppGraph> seededGraph() async {
    final graph = await emptyGraph();
    final store = graph.store;
    await store.create(EntityType.collection, colId, {'title': 'Espresso'});
    await store.create(EntityType.card, cardId, {
      'kind': 'text',
      'collection_id': colId,
      'text': 'hello',
    }, position: 'a0');
    final hash = await sha256Hex(blobBytes);
    await store.create(EntityType.attachment, attId, {
      'kind': 'image',
      'mime': 'image/png',
      'content_hash': hash,
      'size': blobBytes.length,
      'name': null,
    });
    await graph.blobStore.put(hash, blobBytes);
    return graph;
  }

  test('export → import reproduces the projection and the blobs', () async {
    final src = await seededGraph();
    final hash = await sha256Hex(blobBytes);

    final export = await SyncStoreBackupExportRepository(
      graph: src,
    ).exportAll();
    final archive = export.getOrThrow();

    final dst = await emptyGraph();
    final summary = (await SyncStoreBackupImportRepository(
      graph: dst,
    ).importArchive(archive.bytes)).getOrThrow();

    // Three signed ops (collection, card, attachment), all applied; one blob.
    expect(summary.opsApplied, 3);
    expect(summary.opsDeduped, 0);
    expect(summary.opsQuarantined, 0);
    expect(summary.blobsRestored, 1);
    expect(summary.blobsMismatched, 0);

    final collections = await dst.store.readAll(EntityType.collection);
    expect(collections.single.content['title'], 'Espresso');

    final feed = await dst.store.feed(colId);
    expect(feed.single.content['text'], 'hello');

    final attachment = await dst.store.get(EntityType.attachment, attId);
    expect(attachment, isNotNull);
    expect(attachment!.content[AttachmentSchema.colContentHash], hash);

    expect(await dst.blobStore.readBytes(hash), equals(blobBytes));
  });

  test('re-importing the same bundle dedups every op (idempotent)', () async {
    final src = await seededGraph();
    final archive = (await SyncStoreBackupExportRepository(
      graph: src,
    ).exportAll()).getOrThrow();

    final dst = await emptyGraph();
    final importer = SyncStoreBackupImportRepository(graph: dst);

    await importer.importArchive(archive.bytes);
    final second = (await importer.importArchive(archive.bytes)).getOrThrow();

    expect(second.opsApplied, 0);
    expect(second.opsDeduped, 3);
  });

  test(
    'a blob whose bytes do not match its hash is skipped, op still applies',
    () async {
      final src = await seededGraph();
      final archive = (await SyncStoreBackupExportRepository(
        graph: src,
      ).exportAll()).getOrThrow();

      // Corrupt the blob bytes but keep its (now wrong) content-hash name.
      const codec = BackupArchiveCodec();
      final parsed = codec.decode(archive.bytes);
      final tampered = codec.encode(
        manifest: parsed.manifest,
        opLines: parsed.opLines,
        blobs: {
          for (final e in parsed.blobs.entries)
            e.key: Uint8List.fromList([...e.value, 99]),
        },
      );

      final dst = await emptyGraph();
      final summary = (await SyncStoreBackupImportRepository(
        graph: dst,
      ).importArchive(tampered)).getOrThrow();

      expect(summary.blobsMismatched, 1);
      expect(summary.blobsRestored, 0);
      expect(summary.opsApplied, 3); // metadata ops still replay
    },
  );

  test('a non-archive input fails with BackupCorruptArchiveFailure', () async {
    final dst = await emptyGraph();
    final result = await SyncStoreBackupImportRepository(
      graph: dst,
    ).importArchive(Uint8List.fromList([1, 2, 3, 4, 5]));

    expect(result.isFailure, isTrue);
    expect(result.error, isA<BackupCorruptArchiveFailure>());
  });
}
