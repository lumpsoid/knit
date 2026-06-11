/// Async-work descriptors for Timeline (fcis.md §6.4).
sealed class TimelineEffect {
  const TimelineEffect();
}

/// Read the home timeline (§8.6.3) from the projection.
class LoadTimelineEffect extends TimelineEffect {
  const LoadTimelineEffect();
}
