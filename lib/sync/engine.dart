/// Apply engine — the in-memory sketch of spec §8.5, wiring the HLC, the skew
/// guard, and the merge-core into one apply path.
///
/// Out of scope for this sketch (they live in the sqflite/transaction layer):
/// signature verification (§8.5 step 2 — assumed done upstream), `change_log`
/// inserts, `op_id` dedup (§8.5 step 1), envelope-hint cross-checks (step 3), the
/// `quarantine` table, and the `sync_state.cursor`. What's modelled here is the
/// part the rest depends on: skew → clock advance → merge.
///
/// Crash-safety note (spec §8.1/§8.5): production commits the projection write,
/// `change_log` insert, device-clock advance, and cursor bump in ONE transaction.
/// This sketch advances the clock and projection together; persist [DeviceClock.now]
/// in the same transaction as the merged row.
library;

import 'hlc.dart';
import 'merge.dart';
import 'snapshot.dart';

/// Outcome of applying a remote op.
enum ApplyOutcome {
  /// Verified, within skew, merged into the projection (won or lost LWW).
  applied,

  /// `op_id` already seen — skipped as a replay (spec §8.5 step 1). The cursor
  /// still advances past it upstream.
  deduped,

  /// Observed clock too far in the future — quarantined (`reason="skew"`); not
  /// applied, clock NOT advanced (spec §8.3). The cursor still advances past it
  /// upstream (spec §8.8).
  quarantinedSkew,

  /// Signature did not verify over the received bytes — quarantined
  /// (`reason="bad_sig"`); not applied, clock NOT advanced (spec §8.5 step 2).
  quarantinedBadSig,
}

/// Drives local writes and remote applies against one projection + device clock.
class MergeEngine {
  final Projection projection;
  final DeviceClock clock;
  final int maxSkewMs;

  MergeEngine({
    Projection? projection,
    DeviceClock? clock,
    this.maxSkewMs = kMaxSkewMs,
  }) : projection = projection ?? Projection(),
       clock = clock ?? DeviceClock();

  /// Apply a verified remote op — spec §8.5 steps 4–6.
  ///
  /// [physicalNowMs] is this device's wall clock at apply time (used by both the
  /// skew guard and the clock-advance max). Returns whether it was applied or
  /// skew-quarantined.
  ApplyOutcome applyRemote(Snapshot op, int physicalNowMs) {
    final observed = op.observedClock;

    // Step 4: skew guard (future-only).
    if (exceedsSkew(observed.ms, physicalNowMs, maxSkewMs: maxSkewMs)) {
      return ApplyOutcome.quarantinedSkew;
    }

    // Step 5: advance the device clock from the observed clock — always, even on
    // a losing op (observing a timestamp obligates the clock to move past it).
    clock.observe(observed, physicalNowMs);

    // Step 6: merge into the projection.
    projection.apply(op);
    return ApplyOutcome.applied;
  }

  /// Stamp and apply a **local write** — spec §6.8 + §8.2 + §8.4.
  ///
  /// [build] receives a freshly minted content stamp and (for cards) a placement
  /// stamp, and must return the snapshot to write. Which stamp slot a write lands
  /// on is the caller's responsibility per spec §8.4:
  ///   - create card → both stamps fresh;
  ///   - edit/delete card → fresh content stamp, **reuse the prior placement**;
  ///   - reorder card → fresh placement stamp, **reuse the prior content HLC**
  ///     (frozen `hlc_*`, or a stale drag would clobber a concurrent edit);
  ///   - any non-card write → fresh content stamp.
  ///
  /// Each call advances the device clock exactly once and applies the result.
  Snapshot writeLocal(int physicalNowMs, Snapshot Function(Hlc stamp) build) {
    final stamp = clock.localTick(physicalNowMs);
    final op = build(stamp);
    projection.apply(op);
    return op;
  }
}
