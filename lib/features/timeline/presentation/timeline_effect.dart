/// Async-work descriptors for Timeline (fcis.md §6.4).
sealed class TimelineEffect {
  const TimelineEffect();
}

/// Read the home timeline (§8.6.3) from the projection.
class LoadTimelineEffect extends TimelineEffect {
  const LoadTimelineEffect();
}

/// Persist a new collection (§4.1), then open it on success.
class CreateCollectionEffect extends TimelineEffect {
  const CreateCollectionEffect(this.title);
  final String title;
}

/// Navigate to a collection (pure navigation; the shell pushes the UiEffect).
class OpenCollectionEffect extends TimelineEffect {
  const OpenCollectionEffect(this.collectionId);
  final String collectionId;
}
