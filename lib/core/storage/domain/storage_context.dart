/// An opaque handle threaded through storages so a write can join an ambient
/// transaction. Storages that don't need it can ignore it.
///
/// The concrete subtype carries the backend's transactional executor (e.g.
/// [SqliteStorageContext] holds a sqflite `DatabaseExecutor`); a storage impl
/// pattern-matches on the subtype it understands and otherwise falls back to its
/// own default executor. This keeps the storage *interfaces* free of any backend
/// type, which is what makes them testable and swappable in dev mode.
abstract class StorageContext {
  bool get isInTransaction;
}

/// A no-op context for reads / non-transactional writes — the degenerate case
/// where no ambient transaction exists.
class NoOpStorageContext implements StorageContext {
  const NoOpStorageContext();

  @override
  bool get isInTransaction => false;
}
