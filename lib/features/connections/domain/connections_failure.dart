/// Per-feature failure family for the Connections view (result.md §9.3). Each
/// variant carries the original [error] (and [stackTrace] when caught from an
/// exception) so the shell logs the real cause, not a re-typed summary.
sealed class ConnectionsFailure {
  const ConnectionsFailure(this.error, [this.stackTrace]);

  /// The underlying error — a caught exception, or a domain-condition message.
  final Object error;

  /// The stack trace from the caught exception, when there was one.
  final StackTrace? stackTrace;
}

/// Reading an entity's links-out + backlinks from the projection failed, or the
/// focused entity is missing/tombstoned.
class ConnectionsLoadFailure extends ConnectionsFailure {
  const ConnectionsLoadFailure(super.error, [super.stackTrace]);
}

/// Clearing a broken link failed to persist.
class ConnectionsWriteFailure extends ConnectionsFailure {
  const ConnectionsWriteFailure(super.error, [super.stackTrace]);
}
