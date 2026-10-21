import 'dart:convert';
import 'dart:typed_data';

import 'package:knit/app/app_graph.dart';
import 'package:knit/core/attachments/attachments.dart';
import 'package:knit/features/collection_share/domain/collection_share_failure.dart';
import 'package:knit/features/collection_share/domain/collection_share_import_policy.dart';
import 'package:knit/features/collection_share/domain/collection_share_import_repository.dart';
import 'package:knit/features/collection_share/domain/collection_share_models.dart';
import 'package:knit/features/collection_share/infra/collection_share_codec.dart';
import 'package:knit/sync/sync.dart';
import 'package:result_dart/result_dart.dart';

/// [CollectionShareImportRepository] over the graph's [SyncStore] and blob
/// store. Every op goes through [SyncStore.applyRemote] (dedup → verify →
/// skew → one-txn merge), recorded `remote/acked`, so the sync indicator
/// never counts an import. The blobs are re-hashed and only stored when they
/// match their name.
class SyncStoreCollectionShareImportRepository
    implements CollectionShareImportRepository {
  SyncStoreCollectionShareImportRepository({
    required AppGraph graph,
    CollectionShareCodec codec = const CollectionShareCodec(),
    CollectionShareImportPolicy policy = const CollectionShareImportPolicy(),
    DateTime Function() now = DateTime.now,
  }) : _graph = graph,
       _codec = codec,
       _policy = policy,
       _now = now;

  final AppGraph _graph;
  final CollectionShareCodec _codec;
  final CollectionShareImportPolicy _policy;
  final DateTime Function() _now;

  @override
  Future<Result<CollectionShareImportPlan, CollectionShareFailure>> plan(
    Uint8List bytes,
  ) async {
    final CollectionShareBundle bundle;
    try {
      bundle = _codec.decode(bytes);
    } on NewerShareVersionException catch (e, st) {
      return Failure(CollectionShareNewerVersionFailure(e, st));
    } on FormatException catch (e, st) {
      return Failure(CollectionShareCorruptFailure(e, st));
    }

    try {
      final store = _graph.store;
      final snapshots = [for (final op in bundle.ops) op.toSnapshot()];

      final badSignatures = <String>{};
      for (final (i, op) in bundle.ops.indexed) {
        final ok = await store.signer.verify(
          snapshots[i].author,
          utf8.encode(op.payload),
          op.sig,
        );
        if (!ok) badSignatures.add(op.opId);
      }

      final localCreatedBy = <String, String>{};
      for (final type in EntityType.values) {
        final ids = {
          for (final s in snapshots)
            if (s.type == type) s.id,
        };
        if (ids.isEmpty) continue;
        for (final row in await store.getMany(type, ids)) {
          localCreatedBy[row.id] = row.createdBy;
        }
      }

      final rejection = _policy.check(
        bundle,
        badSignatures: badSignatures,
        localCreatedBy: localCreatedBy,
      );
      if (rejection != null) {
        return Failure(
          CollectionShareRejectedFailure(
            rejection,
            'share file refused: ${rejection.name}',
          ),
        );
      }

      // The preview reads the verified ops: the projection they will merge
      // into, not the manifest.
      final preview = Projection()..replay(snapshots);
      final owner = bundle.manifest.owner;
      final collectionId = bundle.manifest.collectionId;
      final collection = preview[collectionId]!;
      final me = await store.hasIdentity() ? await store.authorPubkey() : null;
      return Ok(
        CollectionShareImportPlan(
          bundle: bundle,
          title:
              (collection.content[CollectionSchema.colTitle] as String?)
                  ?.trim() ??
              '',
          cardCount: preview.feed(collectionId).length,
          ownerNickname:
              preview[owner]?.content[ProfileSchema.colNickname] as String?,
          ownerFingerprint: await store.signer.fingerprintOf(owner),
          isUpdate: localCreatedBy.containsKey(collectionId),
          isOwn: owner == me,
        ),
      );
    } catch (e, st) {
      return Failure(CollectionShareImportFailure(e, st));
    }
  }

  @override
  Future<Result<CollectionShareImportResult, CollectionShareFailure>> apply(
    CollectionShareImportPlan plan,
  ) async {
    try {
      // Blobs first, so a card's bytes are there once its op lands.
      var blobsRestored = 0;
      for (final MapEntry(key: hash, value: bytes)
          in plan.bundle.blobs.entries) {
        if (await sha256Hex(bytes) != hash) continue;
        await _graph.blobStore.put(hash, bytes);
        blobsRestored++;
      }

      var applied = 0;
      var deduped = 0;
      for (final op in plan.bundle.ops) {
        switch (await _graph.store.applyRemote(
          op,
          _now().millisecondsSinceEpoch,
        )) {
          case ApplyOutcome.applied:
            applied++;
          case ApplyOutcome.deduped:
            deduped++;
          case ApplyOutcome.quarantinedBadSig:
          case ApplyOutcome.quarantinedSkew:
            break; // kept in quarantine; the rest of the file still lands
        }
      }
      return Ok(
        CollectionShareImportResult(
          collectionId: plan.collectionId,
          opsApplied: applied,
          opsDeduped: deduped,
          blobsRestored: blobsRestored,
        ),
      );
    } catch (e, st) {
      return Failure(CollectionShareImportFailure(e, st));
    }
  }
}
