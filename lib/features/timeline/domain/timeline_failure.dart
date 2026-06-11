/// Per-feature failure family for Timeline (result.md §9.3).
sealed class TimelineFailure {
  const TimelineFailure();
}

/// Reading the home timeline from the projection failed.
class TimelineLoadFailure extends TimelineFailure {
  const TimelineLoadFailure(this.cause);
  final String cause;
}
