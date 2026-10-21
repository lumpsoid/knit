import 'package:knit/core/storage/domain/storage_context.dart';
import 'package:knit/sync/storage/change_log/domain/domain.dart';

/// In-memory [ChangeLogStorage] for dev mode and unit tests — no SQLite, no
/// platform channel. Mirrors the sqflite impl's semantics: monotonic `seq`,
/// `op_id` uniqueness (dedup on append), and the pending filter.
///
/// [StorageContext] is ignored: there is no real transaction to join.
class InMemoryChangeLogStorage implements ChangeLogStorage {
  final List<PersistedOp> _ops = [];
  int _nextSeq = 1;

  @override
  Future<void> ensureSchema({StorageContext? ctx}) async {}

  @override
  Future<bool> hasOp(String opId, {StorageContext? ctx}) async =>
      _ops.any((o) => o.opId == opId);

  @override
  Future<void> append(PersistedOp op, {StorageContext? ctx}) async {
    if (_ops.any((o) => o.opId == op.opId)) return; // dedup (spec §7.3)
    _ops.add(op.copyWith(seq: _nextSeq++));
  }

  @override
  Future<List<PersistedOp>> readOrdered({StorageContext? ctx}) async =>
      List.unmodifiable(_ops); // already appended in seq order

  @override
  Future<List<PersistedOp>> readForEntities(
    Iterable<String> entityIds, {
    StorageContext? ctx,
  }) async {
    final wanted = entityIds.toSet();
    return _ops
        .where((o) => wanted.contains(o.entityId))
        .toList(growable: false);
  }

  @override
  Future<void> deleteForEntities(
    Iterable<String> entityIds, {
    StorageContext? ctx,
  }) async {
    final doomed = entityIds.toSet();
    _ops.removeWhere((o) => doomed.contains(o.entityId));
  }

  @override
  Future<List<PersistedOp>> readPending({StorageContext? ctx}) async => _ops
      .where((o) => o.origin == SyncOrigin.local && !o.acked)
      .toList(growable: false);

  @override
  Future<int> pendingCount({StorageContext? ctx}) async =>
      _ops.where((o) => o.origin == SyncOrigin.local && !o.acked).length;

  @override
  Future<void> markAcked(String opId, {StorageContext? ctx}) async {
    for (var i = 0; i < _ops.length; i++) {
      if (_ops[i].opId == opId) _ops[i] = _ops[i].copyWith(acked: true);
    }
  }

  @override
  Future<void> clear({StorageContext? ctx}) async {
    _ops.clear();
    _nextSeq = 1;
  }
}
