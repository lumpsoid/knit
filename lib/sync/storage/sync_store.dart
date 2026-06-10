import 'package:knit/core/storage/domain/unit_of_work.dart';
import 'package:knit/sync/engine.dart';
import 'package:knit/sync/hlc.dart';
import 'package:knit/sync/merge.dart';
import 'package:knit/sync/snapshot.dart';
import 'package:knit/sync/storage/change_log/change_log.dart';
import 'package:knit/sync/storage/device_clock/device_clock.dart';
import 'package:knit/sync/storage/projection/projection.dart';

/// The persistent apply orchestrator — ties the durable [ChangeLogStorage], the
/// materialized [ProjectionStorage], and the [DeviceClockStorage] to the
/// merge-core (spec §8.5 / §8.9), all through the storage abstractions so the
/// same code runs on sqflite in production and on in-memory fakes in dev/tests.
///
/// Crash-safety (spec §8.5): an apply commits the projection write, the
/// change_log insert, and the device-clock save in **one** [UnitOfWork]
/// transaction, so the persisted state is always internally consistent.
///
/// Out of scope (upstream write-path): canonical serialization + signing
/// (§7.1), signature verification (§8.5 step 2), the quarantine table, and the
/// `sync_state.cursor`. The local write path needs the canonical serializer to
/// build a [PersistedOp], so it composes on top of this rather than living here.
class SyncStore {
  SyncStore({
    required this.changeLog,
    required this.projection,
    required this.deviceClock,
    UnitOfWork unitOfWork = const NoOpUnitOfWork(),
    DeviceClock? clock,
    this.maxSkewMs = kMaxSkewMs,
  })  : _unitOfWork = unitOfWork,
        _clock = clock ?? DeviceClock();

  /// Fully in-memory wiring for dev mode and tests — no SQLite, no transaction.
  factory SyncStore.inMemory({int maxSkewMs = kMaxSkewMs}) => SyncStore(
        changeLog: InMemoryChangeLogStorage(),
        projection: InMemoryProjectionStorage(),
        deviceClock: InMemoryDeviceClockStorage(),
        maxSkewMs: maxSkewMs,
      );

  final ChangeLogStorage changeLog;
  final ProjectionStorage projection;
  final DeviceClockStorage deviceClock;
  final UnitOfWork _unitOfWork;
  final int maxSkewMs;

  DeviceClock _clock;

  /// The in-memory device HLC (loaded from [deviceClock] by [open]/[rebuild]).
  DeviceClock get clock => _clock;

  /// Create tables and restore the persisted device clock. Call once at startup.
  Future<void> open() async {
    await changeLog.ensureSchema();
    await projection.ensureSchema();
    await deviceClock.ensureSchema();
    final saved = await deviceClock.load();
    if (saved != null) _clock.restore(saved);
  }

  // --- Reads (spec §8.6/§8.7) ------------------------------------------------

  Future<Snapshot?> get(EntityType type, String id) =>
      projection.get(type, id);

  Future<List<Snapshot>> feed(String collectionId) =>
      projection.feed(collectionId);

  Future<List<Snapshot>> backlinks(String targetId) =>
      projection.backlinks(targetId);

  /// Pending-sync indicator (spec §6.6) — local ops not yet acked.
  Future<int> pendingCount() => changeLog.pendingCount();

  // --- Apply / rebuild -------------------------------------------------------

  /// Apply a verified remote op and persist it atomically — spec §8.5.
  ///
  /// Dedup by `op_id` (step 1) → skew guard (step 4) → in one transaction: read
  /// current, advance the clock (step 5), merge (step 6), write the winner,
  /// record the op as `remote/acked` (step 7), and save the clock. A
  /// skew-quarantined op is neither merged nor recorded (quarantine is upstream).
  Future<ApplyOutcome> applyRemote(PersistedOp op, int physicalNowMs) async {
    if (await changeLog.hasOp(op.opId)) return ApplyOutcome.deduped;

    final snapshot = op.toSnapshot();
    final observed = snapshot.observedClock;
    if (exceedsSkew(observed.ms, physicalNowMs, maxSkewMs: maxSkewMs)) {
      return ApplyOutcome.quarantinedSkew;
    }

    await _unitOfWork.run((ctx) async {
      final current = await projection.get(snapshot.type, snapshot.id, ctx: ctx);
      _clock.observe(observed, physicalNowMs);
      final winner = merge(current, snapshot);
      await projection.upsert(winner, ctx: ctx);
      await changeLog.append(
        op.copyWith(origin: SyncOrigin.remote, acked: true),
        ctx: ctx,
      );
      await deviceClock.save(_clock.now, ctx: ctx);
    });
    return ApplyOutcome.applied;
  }

  /// Rebuild-from-log — spec §8.9. Replay every op in `seq` order through the
  /// merge-core (order-independent by construction), then, in one transaction,
  /// truncate and re-materialize the projection and recover the device clock
  /// (step 3) past the max stamp ever recorded.
  Future<void> rebuild() async {
    final ops = await changeLog.readOrdered();

    final memory = Projection();
    var recovered = _clock.now;
    for (final op in ops) {
      final snapshot = op.toSnapshot();
      memory.apply(snapshot);
      recovered = Hlc.max(recovered, snapshot.observedClock);
    }
    _clock.restore(recovered);

    await _unitOfWork.run((ctx) async {
      await projection.clear(ctx: ctx);
      for (final row in memory.rows) {
        await projection.upsert(row, ctx: ctx);
      }
      await deviceClock.save(_clock.now, ctx: ctx);
    });
  }
}
