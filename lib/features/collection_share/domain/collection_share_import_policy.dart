import 'package:knit/features/collection_share/domain/collection_share_failure.dart';
import 'package:knit/features/collection_share/domain/collection_share_models.dart';
import 'package:knit/sync/sync.dart';

/// Validates a whole share file before anything is applied
/// (docs/collection_share.md "Import" step 2). Pure: the caller verifies the
/// signatures and reads the local `created_by` of the touched ids first.
class CollectionShareImportPolicy {
  const CollectionShareImportPolicy();

  /// The first reason [bundle] must be refused, or null when it may be
  /// imported. [badSignatures] holds the op ids whose signature failed;
  /// [localCreatedBy] maps each touched id that exists here to its
  /// `created_by`.
  ShareRejection? check(
    CollectionShareBundle bundle, {
    required Set<String> badSignatures,
    required Map<String, String> localCreatedBy,
  }) {
    final manifest = bundle.manifest;
    final owner = manifest.owner;
    final collectionId = manifest.collectionId;
    final snapshots = [for (final op in bundle.ops) (op, op.toSnapshot())];
    final cardIds = {
      for (final (_, s) in snapshots)
        if (s.isCard) s.id,
    };
    final sources = {collectionId, ...cardIds};

    var hasCollection = false;
    for (final (op, s) in snapshots) {
      if (op.entityId != s.id || op.entityType != s.type.name) {
        return ShareRejection.malformed;
      }
      if (badSignatures.contains(op.opId)) return ShareRejection.badSignature;

      // A profile is self-signed; everything else is the owner's own.
      final signer = s.type == EntityType.profile ? s.id : owner;
      if (s.author != signer || s.createdBy != signer) {
        return ShareRejection.foreignAuthor;
      }

      final inside = switch (s.type) {
        EntityType.collection => s.id == collectionId,
        EntityType.card =>
          s.content[CardSchema.colCollectionId] == collectionId,
        EntityType.link => sources.contains(s.content[LinkSchema.colSourceId]),
        EntityType.profile || EntityType.attachment => true,
      };
      if (!inside) return ShareRejection.outsideCollection;
      if (s.type == EntityType.collection) hasCollection = true;

      final local = localCreatedBy[s.id];
      if (local != null && local != s.createdBy) {
        return ShareRejection.foreignOverwrite;
      }
    }
    return hasCollection ? null : ShareRejection.outsideCollection;
  }
}
