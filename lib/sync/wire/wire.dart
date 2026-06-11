/// Wire format v1 (spec §7) — the canonical signed bytes and the sig-keyed
/// `op_id`. Pure Dart, no deps, so it round-trips with [Snapshot.fromPayload]
/// and can be golden-tested byte-for-byte against the §7.4 worked examples.
library;

export 'canonical.dart';
export 'op_id.dart';
