/// Per-feature failure family for the sync status marker (result.md §9.3).
/// Carries the original [error] (and [stackTrace] when caught from an
/// exception) so the shell logs the real cause, not a re-typed summary.
sealed class SyncStatusFailure {
  const SyncStatusFailure(this.error, [this.stackTrace]);

  /// The underlying error — a caught exception, or a domain-condition message.
  final Object error;

  /// The stack trace from the caught exception, when there was one.
  final StackTrace? stackTrace;
}

/// Reading the pending-op count from the change log (§6.6) failed.
class SyncStatusReadFailure extends SyncStatusFailure {
  const SyncStatusReadFailure(super.error, [super.stackTrace]);
}
