/// Knit sync core — the client-side merge/apply engine and HLC (spec §8).
///
/// Pure Dart, Flutter-free, so the local-first correctness gates (spec §9.1) can
/// be unit-tested in isolation. Layers:
///   - [Hlc] / [DeviceClock] — the Hybrid Logical Clock (spec §8.1–8.3).
///   - [Snapshot] — a parsed, verified entity op (spec §6.3/§6.4/§7.4).
///   - [compareContent] / [comparePlacement] / [merge] / [Projection] — the
///     merge-core (spec §6.9/§8.5/§8.7/§8.9).
///   - [MergeEngine] — skew → clock advance → merge (spec §8.5).
library;

export 'hlc.dart';
export 'snapshot.dart';
export 'merge.dart';
export 'engine.dart';
export 'wire/wire.dart';
export 'identity/identity.dart';
export 'storage/storage.dart';
