import 'package:knit/app/app_graph.dart';
import 'package:knit/core/ownership/collection_ownership.dart';
import 'package:knit/features/timeline/domain/timeline_failure.dart';
import 'package:knit/features/timeline/domain/timeline_owner_read_repository.dart';
import 'package:knit/sync/sync.dart';
import 'package:result_dart/result_dart.dart';

/// [TimelineOwnerReadRepository] over the graph's [SyncStore]: ownership by
/// [CollectionOwnership], the handle from the creator's `profile` (carried in
/// the share file) and the signer's fingerprint.
class SyncStoreTimelineOwnerRepository implements TimelineOwnerReadRepository {
  SyncStoreTimelineOwnerRepository({required AppGraph graph}) : _graph = graph;

  final AppGraph _graph;

  @override
  Future<Result<Map<String, String>, TimelineFailure>> loadImportedOwners(
    Iterable<CollectionSummary> collections,
  ) async {
    try {
      final store = _graph.store;
      final me = await store.authorPubkey();
      final imported = [
        for (final c in collections)
          if (!CollectionOwnership.of(c.createdBy, me).canEdit) c,
      ];
      if (imported.isEmpty) return const Ok({});
      final profiles = {
        for (final p in await store.getMany(EntityType.profile, {
          for (final c in imported) c.createdBy,
        }))
          p.id: p.content[ProfileSchema.colNickname] as String?,
      };
      final handles = <String, String>{};
      for (final c in imported) {
        final fingerprint = await store.signer.fingerprintOf(c.createdBy);
        handles[c.collectionId] = '${profiles[c.createdBy] ?? ''}#$fingerprint';
      }
      return Ok(handles);
    } catch (e, st) {
      return Failure(TimelineLoadFailure(e, st));
    }
  }
}
