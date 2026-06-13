import 'package:knit/app/app_graph.dart';
import 'package:knit/features/card_edit/domain/card_edit_failure.dart';
import 'package:knit/features/card_edit/domain/card_edit_write_repository.dart';
import 'package:knit/sync/sync.dart';
import 'package:result_dart/result_dart.dart';

/// [CardEditWriteRepository] over the graph's [SyncStore] §6.8 write path. Each
/// edit is one signed local write committed in a single transaction (§8.5);
/// content stamp bumps, placement frozen (§8.4). The `kind`/`attachment_id`
/// fields overlay the prior content (the engine merges only changed keys), so
/// flipping the image never disturbs the card's text and vice-versa.
class SyncStoreCardEditWriteRepository implements CardEditWriteRepository {
  SyncStoreCardEditWriteRepository({required AppGraph graph}) : _graph = graph;

  final AppGraph _graph;

  @override
  Future<Result<String, CardEditFailure>> editCard({
    required String cardId,
    String? text,
  }) =>
      _write(() async {
        await _graph.store.edit(EntityType.card, cardId, {'text': text});
        return cardId;
      });

  @override
  Future<Result<String, CardEditFailure>> setCardImage({
    required String cardId,
    required String attachmentId,
  }) =>
      _write(() async {
        await _graph.store.edit(EntityType.card, cardId, {
          'kind': 'image',
          'attachment_id': attachmentId,
        });
        return cardId;
      });

  @override
  Future<Result<String, CardEditFailure>> removeCardImage({
    required String cardId,
  }) =>
      _write(() async {
        await _graph.store.edit(EntityType.card, cardId, {
          'kind': 'text',
          'attachment_id': null,
        });
        return cardId;
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
