import 'package:knit/core/storage/domain/storage_context.dart';
import 'package:knit/sync/storage/quarantine/domain/domain.dart';

/// In-memory [QuarantineStorage] for dev mode and tests. Insertion-ordered.
class InMemoryQuarantineStorage implements QuarantineStorage {
  final Map<String, QuarantinedOp> _ops = {};

  @override
  Future<void> ensureSchema({StorageContext? ctx}) async {}

  @override
  Future<void> add(QuarantinedOp op, {StorageContext? ctx}) async {
    _ops.putIfAbsent(op.opId, () => op); // re-seen op_id ignored
  }

  @override
  Future<List<QuarantinedOp>> readAll({StorageContext? ctx}) async =>
      _ops.values.toList();

  @override
  Future<void> remove(String opId, {StorageContext? ctx}) async =>
      _ops.remove(opId);

  @override
  Future<void> clear({StorageContext? ctx}) async => _ops.clear();
}
