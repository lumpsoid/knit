/// `op_id` — the sig-keyed idempotency key (spec §7.3, final v1 form).
///
/// `op_id = "<entity_id>@<hlc_ms>.<hlc_counter>.<sig16>"`, `sig16` = first 16 hex
/// chars of the signature. It is a pure lookup key — **never sorted or compared
/// for order** — so the trailing `sig16` closes the silent dedup-collision
/// classes (§7.3 cases 1–3, notably a reorder reusing the frozen content HLC)
/// without reintroducing a string-clock.
library;

import 'package:knit/sync/hlc.dart';
import 'package:knit/sync/snapshot.dart';

abstract class OpId {
  /// First 16 hex chars of [sig] (8 bytes — enough to beat a birthday collision
  /// among a handful of devices on one `(entity_id, hlc)` triple, §7.3).
  static String sig16(String sig) => sig.length >= 16 ? sig.substring(0, 16) : sig;

  /// Build the key from its parts. Uses the **content** `hlc_*` (which a reorder
  /// leaves frozen, §8.4) — distinctness comes from `sig16`, not the HLC.
  static String build({
    required String entityId,
    required Hlc hlc,
    required String sig,
  }) =>
      '$entityId@${hlc.ms}.${hlc.counter}.${sig16(sig)}';

  /// Convenience for an already-signed [Snapshot].
  static String ofSnapshot(Snapshot s) =>
      build(entityId: s.id, hlc: s.hlc, sig: s.sig);
}
