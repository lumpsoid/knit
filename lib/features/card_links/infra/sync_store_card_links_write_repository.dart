import 'package:knit/app/app_graph.dart';
import 'package:knit/core/ids/id_generator.dart';
import 'package:knit/features/card_links/domain/card_links_failure.dart';
import 'package:knit/features/card_links/domain/card_links_models.dart';
import 'package:knit/features/card_links/domain/card_links_write_repository.dart';
import 'package:knit/features/connections/domain/connections_models.dart';
import 'package:knit/sync/sync.dart';
import 'package:result_dart/result_dart.dart';

/// [CardLinksWriteRepository] over the graph's [SyncStore] §6.8 write path.
/// Adding a link mints an id via the injected [IdGenerator] (§6.1) and writes a
/// signed `link` record whose `target_type` is generic (collection or card) —
/// unless a live link already joins the pair (§6.4), which then stands and
/// nothing is written. Removing one is a signed delete of it and of every
/// duplicate of its pair. A batch of links (optionally with the new collection
/// they point at) goes through [SyncStore.createLinks]. Each commits in a
/// single transaction (§8.5).
class SyncStoreCardLinksWriteRepository implements CardLinksWriteRepository {
  SyncStoreCardLinksWriteRepository({
    required AppGraph graph,
    required IdGenerator ids,
  }) : _graph = graph,
       _ids = ids;

  final AppGraph _graph;
  final IdGenerator _ids;

  @override
  Future<Result<String, CardLinksFailure>> addLink({
    required ConnectedEntityKind sourceKind,
    required String sourceId,
    required ConnectedEntityKind targetKind,
    required String targetId,
  }) => _write(
    () => _graph.store.createLink(
      linkId: _ids.newId(),
      sourceType: EntityType.fromTag(sourceKind.tag),
      sourceId: sourceId,
      targetType: EntityType.fromTag(targetKind.tag),
      targetId: targetId,
    ),
  );

  @override
  Future<Result<LinksAdded, CardLinksFailure>> addLinks({
    required List<String> sourceIds,
    required ConnectedEntityKind targetKind,
    required String targetId,
  }) => _write(() async {
    final ops = await _graph.store.createLinks(
      _links(sourceIds, EntityType.fromTag(targetKind.tag), targetId),
    );
    return LinksAdded(targetId: targetId, count: ops.length);
  });

  @override
  Future<Result<LinksAdded, CardLinksFailure>> addLinksToNewCollection({
    required List<String> sourceIds,
    required String title,
  }) => _write(() async {
    final collectionId = _ids.newId();
    final ops = await _graph.store.createLinks(
      _links(sourceIds, EntityType.collection, collectionId),
      newCollection: (
        id: collectionId,
        content: {'title': title, 'cover_attachment_id': null},
      ),
    );
    // The first op made the collection; the rest are its links.
    return LinksAdded(targetId: collectionId, count: ops.length - 1);
  });

  /// A new link from each card of [sourceIds] to the [targetType] entity
  /// [targetId], each with a fresh id.
  List<({String linkId, LinkPair pair})> _links(
    List<String> sourceIds,
    EntityType targetType,
    String targetId,
  ) => [
    for (final sourceId in sourceIds)
      (
        linkId: _ids.newId(),
        pair: LinkPair(
          sourceType: EntityType.card.name,
          sourceId: sourceId,
          targetType: targetType.name,
          targetId: targetId,
        ),
      ),
  ];

  @override
  Future<Result<String, CardLinksFailure>> removeLink(String linkId) =>
      _write(() async {
        await _graph.store.deleteLink(linkId);
        return linkId;
      });

  Future<Result<T, CardLinksFailure>> _write<T extends Object>(
    Future<T> Function() op,
  ) async {
    try {
      return Ok(await op());
    } catch (e, st) {
      return Failure(CardLinksWriteFailure(e, st));
    }
  }
}
