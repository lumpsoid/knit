/// Per-feature failure family for the sync status marker (result.md §9.3).
sealed class SyncStatusFailure {
  const SyncStatusFailure();
}

/// Reading the pending-op count from the change log (§6.6) failed.
class SyncStatusReadFailure extends SyncStatusFailure {
  const SyncStatusReadFailure(this.cause);
  final String cause;
}
