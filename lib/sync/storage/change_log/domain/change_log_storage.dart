import 'package:knit/core/storage/domain/storage_context.dart';
import 'package:knit/sync/storage/change_log/domain/persisted_op.dart';

/// The durable sync log (spec §6.6), abstracted so the merge/apply engine never
/// depends on a database package. Production uses the sqflite impl; dev and tests
/// use the in-memory impl. Every method optionally joins an ambient transaction
/// via [StorageContext].
abstract class ChangeLogStorage {
  /// Create the table if needed (sqflite); a no-op for in-memory.
  Future<void> ensureSchema({StorageContext? ctx});

  /// Idempotency check — spec §8.5 step 1. True if this `op_id` was already seen.
  Future<bool> hasOp(String opId, {StorageContext? ctx});

  /// Append an op. Duplicate `op_id`s are ignored (a true resend is
  /// byte-identical → same `op_id`, spec §7.3), so this is safe to retry.
  Future<void> append(PersistedOp op, {StorageContext? ctx});

  /// All ops in `seq ASC` — the replay order for rebuild-from-log (spec §8.9).
  Future<List<PersistedOp>> readOrdered({StorageContext? ctx});

  /// Every op of the entities in [entityIds], in `seq ASC` — the history a
  /// collection share picks its winners from.
  Future<List<PersistedOp>> readForEntities(
    Iterable<String> entityIds, {
    StorageContext? ctx,
  });

  /// Delete every op of the entities in [entityIds] — the local purge of an
  /// imported collection, so rebuild-from-log (§8.9) no longer brings it back.
  Future<void> deleteForEntities(
    Iterable<String> entityIds, {
    StorageContext? ctx,
  });

  /// Local ops not yet acked by the relay, in push order (`seq ASC`).
  Future<List<PersistedOp>> readPending({StorageContext? ctx});

  /// Pending-indicator count = `origin='local' AND acked=0` (spec §6.6).
  Future<int> pendingCount({StorageContext? ctx});

  /// Mark a local op confirmed by the relay (spec §7.5 push ack).
  Future<void> markAcked(String opId, {StorageContext? ctx});

  /// Drop everything (e.g. logout / test reset).
  Future<void> clear({StorageContext? ctx});
}
