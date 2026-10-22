import 'package:knit/features/collection_share/domain/collection_share_failure.dart';
import 'package:knit/features/collection_share/domain/collection_share_models.dart';
import 'package:knit/sync/sync.dart';

/// Validates a whole share file before anything is applied
/// (docs/collection_share.md "Import" step 2) — the primary collection and
/// every linked one it carries, each under the same rules. Pure: the caller
/// verifies the signatures and reads the local `created_by` of the touched
/// ids first.
class CollectionShareImportPolicy {
  const CollectionShareImportPolicy();

  /// The first reason [bundle] must be refused, or null when it may be
  /// imported. [badSignatures] holds the op ids whose signature failed;
  /// [localCreatedBy] maps each touched id that exists here to its
  /// `created_by`.
  ///
  /// Each op belongs to one declared collection — a collection by its id, a
  /// card by its `collection_id`, a link by its source (the collection or one
  /// of its cards in the file) — and must be signed and created by that
  /// collection's owner; so each collection's ops stay within its own scope.
  /// A profile is self-signed, and an attachment is one of the owners'.
  ShareRejection? check(
    CollectionShareBundle bundle, {
    required Set<String> badSignatures,
    required Map<String, String> localCreatedBy,
  }) {
    final manifest = bundle.manifest;
    final owners = manifest.owners;
    if (owners.length != manifest.included.length + 1) {
      return ShareRejection.malformed; // a collection declared twice
    }
    final snapshots = [for (final op in bundle.ops) (op, op.toSnapshot())];
    final cardCollection = {
      for (final (_, s) in snapshots)
        if (s.isCard) s.id: s.content[CardSchema.colCollectionId] as String?,
    };
    String? collectionOfSource(Object? id) =>
        owners.containsKey(id) ? id! as String : cardCollection[id];

    final seen = <String>{};
    for (final (op, s) in snapshots) {
      if (op.entityId != s.id || op.entityType != s.type.name) {
        return ShareRejection.malformed;
      }
      if (badSignatures.contains(op.opId)) return ShareRejection.badSignature;

      final String? signer;
      switch (s.type) {
        case EntityType.profile:
          signer = s.id;
        case EntityType.attachment:
          signer = owners.containsValue(s.author) ? s.author : null;
        case EntityType.collection || EntityType.card || EntityType.link:
          final collectionId = switch (s.type) {
            EntityType.collection => s.id,
            EntityType.card => s.content[CardSchema.colCollectionId],
            _ => collectionOfSource(s.content[LinkSchema.colSourceId]),
          };
          signer = owners[collectionId];
          if (signer == null) return ShareRejection.outsideCollection;
      }
      if (signer == null || s.author != signer || s.createdBy != signer) {
        return ShareRejection.foreignAuthor;
      }
      if (s.type == EntityType.collection) seen.add(s.id);

      final local = localCreatedBy[s.id];
      if (local != null && local != s.createdBy) {
        return ShareRejection.foreignOverwrite;
      }
    }
    return seen.containsAll(owners.keys)
        ? null
        : ShareRejection.outsideCollection;
  }
}
