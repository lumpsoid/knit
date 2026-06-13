import 'package:knit/app/app_graph.dart';
import 'package:knit/features/card_edit/domain/card_edit_failure.dart';
import 'package:knit/features/card_edit/domain/card_edit_write_repository.dart';
import 'package:knit/sync/sync.dart';
import 'package:result_dart/result_dart.dart';

/// [CardEditWriteRepository] over the graph's [SyncStore] §6.8 write path. The
/// edit is one signed local write committed in a single transaction (§8.5);
/// content stamp bumps, placement frozen (§8.4).
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

  Future<Result<String, CardEditFailure>> _write(
    Future<String> Function() op,
  ) async {
    try {
      return Ok(await op());
    } catch (e) {
      return Failure(CardEditWriteFailure(e.toString()));
    }
  }
}
