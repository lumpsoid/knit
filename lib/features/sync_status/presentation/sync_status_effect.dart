/// Async-work descriptors for the sync marker (fcis.md §6.4).
sealed class SyncStatusEffect {
  const SyncStatusEffect();
}

/// Read the pending-op count from the change log (§6.6).
class LoadPendingCountEffect extends SyncStatusEffect {
  const LoadPendingCountEffect();
}
