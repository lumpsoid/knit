/// Per-feature failure family for Timeline (result.md §9.3).
sealed class TimelineFailure {
  const TimelineFailure();
}

/// Reading the home timeline from the projection failed.
class TimelineLoadFailure extends TimelineFailure {
  const TimelineLoadFailure(this.cause);
  final String cause;
}

/// Creating a new collection (inline create, §4.1) failed to persist.
class TimelineWriteFailure extends TimelineFailure {
  const TimelineWriteFailure(this.cause);
  final String cause;
}
