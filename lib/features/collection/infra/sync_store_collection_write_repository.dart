import 'package:knit/app/app_graph.dart';
import 'package:knit/core/ids/id_generator.dart';
import 'package:knit/features/collection/domain/collection_failure.dart';
import 'package:knit/features/collection/domain/collection_models.dart';
import 'package:knit/features/collection/domain/collection_write_repository.dart';
import 'package:knit/sync/sync.dart';
import 'package:result_dart/result_dart.dart';

/// [CollectionWriteRepository] over the graph's [SyncStore] §6.8 write path.
/// Each method is one signed local write committed in a single transaction
/// (§8.5); ids are minted via the injected [IdGenerator] (§6.1) and positions
/// arrive pre-computed from the pure updater, so no ordering logic lives here.
class SyncStoreCollectionWriteRepository implements CollectionWriteRepository {
  SyncStoreCollectionWriteRepository({
    required AppGraph graph,
    required IdGenerator ids,
  })  : _graph = graph,
        _ids = ids;

  final AppGraph _graph;
  final IdGenerator _ids;

  @override
  Future<Result<String, CollectionFailure>> addCard({
    required String collectionId,
    required CardKind kind,
    required String position,
    String? text,
  }) =>
      _write(() async {
        final id = _ids.newId();
        await _graph.store.create(
          EntityType.card,
          id,
          {'collection_id': collectionId, 'kind': kind.tag, 'text': text},
          position: position,
        );
        return id;
      });

  @override
  Future<Result<String, CollectionFailure>> deleteCard(String cardId) =>
      _write(() async {
        await _graph.store.delete(EntityType.card, cardId);
        return cardId;
      });

  @override
  Future<Result<String, CollectionFailure>> reorderCard(
    String cardId,
    String position,
  ) =>
      _write(() async {
        await _graph.store.reorder(cardId, position);
        return cardId;
      });

  @override
  Future<Result<String, CollectionFailure>> linkCardToCollection({
    required String cardId,
    required String collectionId,
  }) =>
      _write(() async {
        final id = _ids.newId();
        await _graph.store.create(EntityType.link, id, {
          'source_type': EntityType.card.name,
          'source_id': cardId,
          'target_type': EntityType.collection.name,
          'target_id': collectionId,
          'label': null,
        });
        return id;
      });

  @override
  Future<Result<String, CollectionFailure>> editTitle(
    String collectionId,
    String title,
  ) =>
      _write(() async {
        await _graph.store.edit(EntityType.collection, collectionId, {
          'title': title,
        });
        return collectionId;
      });

  Future<Result<String, CollectionFailure>> _write(
    Future<String> Function() op,
  ) async {
    try {
      return Ok(await op());
    } catch (e) {
      return Failure(CollectionWriteFailure(e.toString()));
    }
  }
}
