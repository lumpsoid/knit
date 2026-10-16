import 'package:knit/app/app_graph.dart';
import 'package:knit/features/collection_details/domain/collection_details_failure.dart';
import 'package:knit/features/collection_details/domain/collection_details_write_repository.dart';
import 'package:knit/sync/sync.dart';
import 'package:result_dart/result_dart.dart';

/// [CollectionDetailsWriteRepository] over the graph's [SyncStore] §6.8 write
/// path. Each edit is one signed local write committed in a single transaction
/// (§8.5); the content stamp bumps. The fields overlay the prior content (the
/// engine merges only changed keys), so editing the title never disturbs the
/// cover and vice-versa.
class SyncStoreCollectionDetailsWriteRepository
    implements CollectionDetailsWriteRepository {
  SyncStoreCollectionDetailsWriteRepository({required AppGraph graph})
    : _graph = graph;

  final AppGraph _graph;

  @override
  Future<Result<String, CollectionDetailsFailure>> editDetails({
    required String collectionId,
    required String title,
    String? description,
  }) => _write(() async {
    await _graph.store.edit(EntityType.collection, collectionId, {
      'title': title,
      'description': description,
    });
    return collectionId;
  });

  @override
  Future<Result<String, CollectionDetailsFailure>> setCover({
    required String collectionId,
    required String attachmentId,
  }) => _write(() async {
    await _graph.store.edit(EntityType.collection, collectionId, {
      'cover_attachment_id': attachmentId,
    });
    return collectionId;
  });

  @override
  Future<Result<String, CollectionDetailsFailure>> removeCover({
    required String collectionId,
  }) => _write(() async {
    await _graph.store.edit(EntityType.collection, collectionId, {
      'cover_attachment_id': null,
    });
    return collectionId;
  });

  Future<Result<String, CollectionDetailsFailure>> _write(
    Future<String> Function() op,
  ) async {
    try {
      return Ok(await op());
    } catch (e, st) {
      return Failure(CollectionDetailsWriteFailure(e, st));
    }
  }
}
