import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:knit/app/app_graph.dart';
import 'package:knit/core/attachments/attachments.dart';
import 'package:knit/features/backup/domain/backup_failure.dart';
import 'package:knit/features/backup/domain/backup_models.dart';
import 'package:knit/features/backup/infra/argon2_identity_key_cipher.dart';
import 'package:knit/features/backup/infra/backup_archive_codec.dart';
import 'package:knit/features/backup/infra/sync_store_backup_export_repository.dart';
import 'package:knit/features/backup/infra/sync_store_backup_import_repository.dart';
import 'package:knit/sync/sync.dart';

/// Tiny Argon2id settings so the tests don't spend seconds per derivation.
final testCipher = Argon2IdentityKeyCipher(
  params: const KdfParams(memoryKib: 8, iterations: 1, parallelism: 1),
);

const passphrase = 'correct horse';

SyncStoreBackupExportRepository exporter(AppGraph graph) =>
    SyncStoreBackupExportRepository(graph: graph, cipher: testCipher);

SyncStoreBackupImportRepository importer(AppGraph graph) =>
    SyncStoreBackupImportRepository(graph: graph, cipher: testCipher);

/// Plan [bytes] onto [graph] and merge them (the same-identity restore).
Future<ImportSummary> mergeInto(AppGraph graph, Uint8List bytes) async {
  final repo = importer(graph);
  final plan = (await repo.plan(bytes)).getOrThrow();
  expect(plan.kind, RestoreKind.merge);
  return (await repo.merge(plan.bundle)).getOrThrow();
}

void main() {
  const colId = 'col-1';
  const cardId = 'card-1';
  const attId = 'att-1';
  final blobBytes = Uint8List.fromList([10, 20, 30, 40, 50]);

  /// A fresh in-memory graph (store + blob store), with identity provisioned.
  Future<AppGraph> emptyGraph({String identity = 'fake'}) async {
    final graph = AppGraph()
      ..bindStore(
        SyncStore.inMemory(signer: FakeSigner(identitySeed: identity)),
      )
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

    final export = await exporter(src).exportAll(passphrase);
    final archive = export.getOrThrow();

    final dst = await emptyGraph();
    final summary = await mergeInto(dst, archive.bytes);

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
    final archive = (await exporter(src).exportAll(passphrase)).getOrThrow();

    final dst = await emptyGraph();
    await mergeInto(dst, archive.bytes);
    final second = await mergeInto(dst, archive.bytes);

    expect(second.opsApplied, 0);
    expect(second.opsDeduped, 3);
  });

  test(
    'a blob whose bytes do not match its hash is skipped, op still applies',
    () async {
      final src = await seededGraph();
      final archive = (await exporter(src).exportAll(passphrase)).getOrThrow();

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
      final summary = await mergeInto(dst, tampered);

      expect(summary.blobsMismatched, 1);
      expect(summary.blobsRestored, 0);
      expect(summary.opsApplied, 3); // metadata ops still replay
    },
  );

  test('a non-archive input fails with BackupCorruptArchiveFailure', () async {
    final dst = await emptyGraph();
    final result = await importer(
      dst,
    ).plan(Uint8List.fromList([1, 2, 3, 4, 5]));

    expect(result.isFailure, isTrue);
    expect(result.error, isA<BackupCorruptArchiveFailure>());
  });

  group('the bundle carries the keypair', () {
    test('the exported identity is sealed, not in the clear', () async {
      final src = await seededGraph();
      final archive = (await exporter(src).exportAll(passphrase)).getOrThrow();

      final sealed = const BackupArchiveCodec().decode(archive.bytes).identity!;
      final keypair = await src.store.exportKeypair();
      expect(sealed.publicKeyHex, keypair.publicKeyHex);
      expect(sealed.cipherText, isNot(equals(keypair.secretKey)));
    });

    test('another identity plans as a device replace', () async {
      final src = await seededGraph();
      final archive = (await exporter(src).exportAll(passphrase)).getOrThrow();

      final dst = await emptyGraph(identity: 'other');
      final plan = (await importer(dst).plan(archive.bytes)).getOrThrow();
      expect(plan.kind, RestoreKind.replaceDevice);
    });

    test('replacing a device adopts the key and drops its old data', () async {
      final src = await seededGraph();
      final srcAuthor = await src.store.authorPubkey();
      final archive = (await exporter(src).exportAll(passphrase)).getOrThrow();

      final dst = await emptyGraph(identity: 'other');
      await dst.store.create(EntityType.collection, 'mine', {'title': 'Old'});
      final repo = importer(dst);
      final plan = (await repo.plan(archive.bytes)).getOrThrow();

      final summary = (await repo.replaceDevice(
        plan.bundle,
        passphrase,
      )).getOrThrow();

      expect(summary.opsApplied, 3);
      expect(await dst.store.authorPubkey(), srcAuthor);
      final titles = (await dst.store.readAll(
        EntityType.collection,
      )).map((c) => c.content['title']);
      expect(titles, ['Espresso']);
      // New writes are signed by the adopted key and verify as such.
      await dst.store.create(EntityType.collection, 'next', {'title': 'New'});
      final latest = (await dst.store.get(EntityType.collection, 'next'))!;
      expect(latest.author, srcAuthor);
    });

    test('a wrong passphrase fails and leaves the device untouched', () async {
      final src = await seededGraph();
      final archive = (await exporter(src).exportAll(passphrase)).getOrThrow();

      final dst = await emptyGraph(identity: 'other');
      final authorBefore = await dst.store.authorPubkey();
      await dst.store.create(EntityType.collection, 'mine', {'title': 'Old'});
      final repo = importer(dst);
      final plan = (await repo.plan(archive.bytes)).getOrThrow();

      final result = await repo.replaceDevice(plan.bundle, 'wrong horse');

      expect(result.error, isA<BackupWrongPassphraseFailure>());
      expect(await dst.store.authorPubkey(), authorBefore);
      expect(await dst.store.readAll(EntityType.collection), hasLength(1));
    });

    test('a device without an identity restores the bundle\'s', () async {
      final src = await seededGraph();
      final archive = (await exporter(src).exportAll(passphrase)).getOrThrow();

      final dst = AppGraph()
        ..bindStore(SyncStore.inMemory(signer: FakeSigner(identitySeed: 'x')))
        ..bindBlobStore(InMemoryAttachmentBlobStore());
      await dst.store.open(provisionIdentity: false);
      final repo = importer(dst);
      final plan = (await repo.plan(archive.bytes)).getOrThrow();
      expect(plan.kind, RestoreKind.replaceDevice);

      (await repo.replaceDevice(plan.bundle, passphrase)).getOrThrow();

      expect(await dst.store.hasIdentity(), isTrue);
      expect(await dst.store.authorPubkey(), await src.store.authorPubkey());
    });

    test('a v1 bundle (no keypair) cannot set up a fresh device', () async {
      final src = await seededGraph();
      final archive = (await exporter(src).exportAll(passphrase)).getOrThrow();
      const codec = BackupArchiveCodec();
      final parsed = codec.decode(archive.bytes);
      final v1 = codec.encode(
        manifest: parsed.manifest,
        opLines: parsed.opLines,
        blobs: parsed.blobs,
      );

      final dst = AppGraph()
        ..bindStore(SyncStore.inMemory(signer: FakeSigner(identitySeed: 'x')))
        ..bindBlobStore(InMemoryAttachmentBlobStore());
      await dst.store.open(provisionIdentity: false);
      final plan = (await importer(dst).plan(v1)).getOrThrow();
      expect(plan.kind, RestoreKind.missingIdentity);
    });
  });
}
