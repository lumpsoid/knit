/// Per-feature failure family for Timeline (result.md §9.3). Each variant
/// carries the original [error] (and [stackTrace] when caught from an
/// exception) so the shell logs the real cause, not a re-typed summary.
sealed class TimelineFailure {
  const TimelineFailure(this.error, [this.stackTrace]);

  /// The underlying error — a caught exception, or a domain-condition message.
  final Object error;

  /// The stack trace from the caught exception, when there was one.
  final StackTrace? stackTrace;
}

/// Reading the home timeline from the projection failed.
class TimelineLoadFailure extends TimelineFailure {
  const TimelineLoadFailure(super.error, [super.stackTrace]);
}

/// Creating a new collection (inline create, §4.1) failed to persist.
class TimelineWriteFailure extends TimelineFailure {
  const TimelineWriteFailure(super.error, [super.stackTrace]);
}
