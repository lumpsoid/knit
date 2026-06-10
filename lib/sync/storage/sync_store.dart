import 'package:knit/core/storage/domain/storage_context.dart';
import 'package:knit/sync/engine.dart';
import 'package:knit/sync/hlc.dart';
import 'package:knit/sync/merge.dart';
import 'package:knit/sync/storage/change_log/domain/domain.dart';

/// Glues the durable [ChangeLogStorage] to the in-memory merge-core
/// ([MergeEngine] + [Projection]) — the part of the apply path that touches
/// persistence (spec §8.5 / §8.9).
///
/// The storage dependency is the abstract interface, so a [SyncStore] runs the
/// same against sqflite in production and an in-memory fake in tests.
///
/// Out of scope here (upstream write-path / transaction layer): canonical
/// serialization + signing (spec §7.1), signature verification (§8.5 step 2),
/// the quarantine table, `sync_state.cursor`, and committing the projection +
/// log + device-clock in one transaction (§8.5). Those compose around this via a
/// `UnitOfWork`.
class SyncStore {
  SyncStore({required this.changeLog, MergeEngine? engine})
      : engine = engine ?? MergeEngine();

  final ChangeLogStorage changeLog;
  final MergeEngine engine;

  Projection get projection => engine.projection;

  /// Rebuild-from-log — spec §8.9. Replay every op in `seq` order through the
  /// merge-core (order-independent by construction) and recover the device clock
  /// as a safety net (§8.9 step 3): set it `>=` the max stamp ever recorded, so
  /// post-rebuild local writes stay strictly monotone even if the persisted
  /// clock was lost.
  Future<void> rebuild({StorageContext? ctx}) async {
    final ops = await changeLog.readOrdered(ctx: ctx);
    var recovered = engine.clock.now;
    for (final op in ops) {
      final snapshot = op.toSnapshot();
      engine.projection.apply(snapshot);
      recovered = Hlc.max(recovered, snapshot.observedClock);
    }
    engine.clock.restore(recovered);
  }

  /// Apply a verified remote op and persist it — spec §8.5.
  ///
  /// Dedup by `op_id` (step 1) → skew guard + clock advance + merge (steps 4–6,
  /// via [MergeEngine.applyRemote]) → record into the log (step 7). The op is
  /// stored as `origin=remote, acked=1`. A skew-quarantined op is neither merged
  /// nor recorded here (the quarantine table is upstream).
  Future<ApplyOutcome> applyRemote(
    PersistedOp op,
    int physicalNowMs, {
    StorageContext? ctx,
  }) async {
    if (await changeLog.hasOp(op.opId, ctx: ctx)) return ApplyOutcome.deduped;

    final outcome = engine.applyRemote(op.toSnapshot(), physicalNowMs);
    if (outcome == ApplyOutcome.applied) {
      await changeLog.append(
        op.copyWith(origin: SyncOrigin.remote, acked: true),
        ctx: ctx,
      );
    }
    return outcome;
  }
}
