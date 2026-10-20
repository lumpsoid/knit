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
  }) : _graph = graph,
       _ids = ids;

  final AppGraph _graph;
  final IdGenerator _ids;

  @override
  Future<Result<String, CollectionFailure>> addCard({
    required String collectionId,
    required CardKind kind,
    required String position,
    String? text,
    String? attachmentId,
  }) => _write(() async {
    final id = _ids.newId();
    await _graph.store.create(EntityType.card, id, {
      'collection_id': collectionId,
      'kind': kind.tag,
      'text': text,
      // Only an image card carries an attachment; omit the key for
      // text/link cards so their signed payloads stay byte-identical.
      'attachment_id': ?attachmentId,
    }, position: position);
    return id;
  });

  @override
  Future<Result<String, CollectionFailure>> deleteCard(String cardId) =>
      _write(() async {
        await _graph.store.delete(EntityType.card, cardId);
        return cardId;
      });

  @override
  Future<Result<String, CollectionFailure>> deleteCards(List<String> cardIds) =>
      _write(() async {
        await _graph.store.deleteCards(cardIds);
        return cardIds.first;
      });

  @override
  Future<Result<String, CollectionFailure>> reorderCard(
    String cardId,
    String position,
  ) => _write(() async {
    await _graph.store.reorder(cardId, position);
    return cardId;
  });

  @override
  Future<Result<String, CollectionFailure>> setCardsSettled(
    List<String> cardIds, {
    required bool settled,
  }) => _write(() async {
    await _graph.store.setCardsSettled(cardIds, settled: settled);
    return cardIds.first;
  });

  @override
  Future<Result<String, CollectionFailure>> setCardsEmphasized(
    List<String> cardIds, {
    required bool emphasized,
  }) => _write(() async {
    await _graph.store.setCardsEmphasized(cardIds, emphasized: emphasized);
    return cardIds.first;
  });

  @override
  Future<Result<String, CollectionFailure>> moveCards(
    String collectionId,
    Map<String, String> positions,
  ) => _write(() async {
    await _graph.store.moveCards(collectionId, positions);
    return collectionId;
  });

  Future<Result<String, CollectionFailure>> _write(
    Future<String> Function() op,
  ) async {
    try {
      return Ok(await op());
    } catch (e, st) {
      return Failure(CollectionWriteFailure(e, st));
    }
  }
}
