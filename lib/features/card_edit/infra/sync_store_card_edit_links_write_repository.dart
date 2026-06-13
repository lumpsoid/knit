import 'package:knit/app/app_graph.dart';
import 'package:knit/core/ids/id_generator.dart';
import 'package:knit/features/card_edit/domain/card_edit_failure.dart';
import 'package:knit/features/card_edit/domain/card_edit_links_write_repository.dart';
import 'package:knit/features/connections/domain/connections_models.dart';
import 'package:knit/sync/sync.dart';
import 'package:result_dart/result_dart.dart';

/// [CardEditLinksWriteRepository] over the graph's [SyncStore] §6.8 write path.
/// Adding a link mints an id via the injected [IdGenerator] (§6.1) and writes a
/// signed `link` record whose `target_type` is generic (collection or card);
/// removing one is a signed delete of that record. Both commit in a single
/// transaction (§8.5).
class SyncStoreCardEditLinksWriteRepository
    implements CardEditLinksWriteRepository {
  SyncStoreCardEditLinksWriteRepository({
    required AppGraph graph,
    required IdGenerator ids,
  })  : _graph = graph,
        _ids = ids;

  final AppGraph _graph;
  final IdGenerator _ids;

  @override
  Future<Result<String, CardEditFailure>> addLink({
    required String sourceCardId,
    required ConnectedEntityKind targetKind,
    required String targetId,
  }) =>
      _write(() async {
        final id = _ids.newId();
        await _graph.store.create(EntityType.link, id, {
          'source_type': EntityType.card.name,
          'source_id': sourceCardId,
          'target_type': targetKind.tag,
          'target_id': targetId,
          'label': null,
        });
        return id;
      });

  @override
  Future<Result<String, CardEditFailure>> removeLink(String linkId) =>
      _write(() async {
        await _graph.store.delete(EntityType.link, linkId);
        return linkId;
      });

  Future<Result<String, CardEditFailure>> _write(
    Future<String> Function() op,
  ) async {
    try {
      return Ok(await op());
    } catch (e, st) {
      return Failure(CardEditWriteFailure(e, st));
    }
  }
}
