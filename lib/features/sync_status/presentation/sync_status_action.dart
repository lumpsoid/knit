/// Intents + async-result deliveries for the sync marker (fcis.md §6.4).
sealed class SyncStatusAction {
  const SyncStatusAction();
}

/// The marker mounted into a page — load the current count.
class ViewAttached extends SyncStatusAction {
  const ViewAttached();
}

/// Re-read the count (e.g. another page mounted the marker, or a tap).
class RefreshRequested extends SyncStatusAction {
  const RefreshRequested();
}

/// The pending-op count (§6.6) was read.
class PendingCountLoaded extends SyncStatusAction {
  const PendingCountLoaded(this.count);
  final int count;
}

/// Reading the count failed.
class PendingCountFailed extends SyncStatusAction {
  const PendingCountFailed();
}
