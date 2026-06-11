/// Per-feature failure family for the Connections view (result.md §9.3). The
/// shell maps these to user-facing messages; the updater never sees a [Result].
sealed class ConnectionsFailure {
  const ConnectionsFailure();
}

/// Reading an entity's links-out + backlinks from the projection failed, or the
/// focused entity is missing/tombstoned.
class ConnectionsLoadFailure extends ConnectionsFailure {
  const ConnectionsLoadFailure(this.cause);
  final String cause;
}

/// Clearing a broken link failed to persist.
class ConnectionsWriteFailure extends ConnectionsFailure {
  const ConnectionsWriteFailure(this.cause);
  final String cause;
}
