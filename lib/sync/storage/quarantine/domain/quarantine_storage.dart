import 'package:knit/core/storage/domain/storage_context.dart';
import 'package:knit/sync/storage/quarantine/domain/quarantined_op.dart';

/// The set-aside store for ops that failed verification or the skew guard
/// (spec §6.7/§8.8), abstracted like the other storages.
abstract class QuarantineStorage {
  Future<void> ensureSchema({StorageContext? ctx});

  /// Set an op aside. A re-seen `op_id` is ignored (idempotent).
  Future<void> add(QuarantinedOp op, {StorageContext? ctx});

  Future<List<QuarantinedOp>> readAll({StorageContext? ctx});

  /// Drop one op — e.g. a `skew` op cleared for auto-retry (§8.8).
  Future<void> remove(String opId, {StorageContext? ctx});

  Future<void> clear({StorageContext? ctx});
}
