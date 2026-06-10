import 'package:knit/core/storage/domain/storage_context.dart';
import 'package:knit/sync/hlc.dart';

/// Persists the single per-device HLC (spec §6.7), abstracted so the engine
/// never depends on a database package. Save runs inside the same transaction
/// as the op that advanced the clock (spec §8.1) via a [StorageContext].
abstract class DeviceClockStorage {
  Future<void> ensureSchema({StorageContext? ctx});

  /// The persisted clock, or null if never written (fresh device).
  Future<Hlc?> load({StorageContext? ctx});

  /// Persist the current clock value (upsert of the single row).
  Future<void> save(Hlc clock, {StorageContext? ctx});

  Future<void> clear({StorageContext? ctx});
}
