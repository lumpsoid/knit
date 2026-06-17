/// Async-work descriptors for Timeline (fcis.md §6.4).
sealed class TimelineEffect {
  const TimelineEffect();
}

/// Read the home timeline (§8.6.3) from the projection.
class LoadTimelineEffect extends TimelineEffect {
  const LoadTimelineEffect();
}

/// Resolve a collection's cover attachment to its renderable bytes (§7.4.1),
/// so a row can show its cover instead of the lettered-avatar placeholder.
class LoadCoverBytesEffect extends TimelineEffect {
  const LoadCoverBytesEffect(this.attachmentId);
  final String attachmentId;
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

/// Delete a collection (§4.1), then reload the home feed on success.
class DeleteCollectionEffect extends TimelineEffect {
  const DeleteCollectionEffect(this.collectionId);
  final String collectionId;
}
