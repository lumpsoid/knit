import 'package:knit/features/timeline/domain/timeline_order.dart';

/// Async-work descriptors for Timeline (fcis.md §6.4).
sealed class TimelineEffect {
  const TimelineEffect();
}

/// Read the home timeline (§8.6.3) from the projection, plus this device's
/// pinned collection ids.
class LoadTimelineEffect extends TimelineEffect {
  const LoadTimelineEffect();
}

/// The feed shows these collection covers (§7.4.1): hand them to the shared
/// image cache, which loads any it doesn't hold yet, so a row can show its
/// cover instead of the lettered-avatar placeholder.
class ShowCoversEffect extends TimelineEffect {
  const ShowCoversEffect(this.attachmentIds);
  final List<String> attachmentIds;
}

/// The Timeline left: let the shared image cache drop its covers.
class ReleaseCoversEffect extends TimelineEffect {
  const ReleaseCoversEffect();
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

/// Pin or unpin a collection in the device-local pin store (§4.1).
class SetPinnedEffect extends TimelineEffect {
  const SetPinnedEffect(this.collectionId, {required this.pinned});
  final String collectionId;
  final bool pinned;
}

/// Persist the manual Home order in the device-local store (§4.1); an empty
/// order clears it.
class SaveOrderEffect extends TimelineEffect {
  const SaveOrderEffect(this.order);
  final TimelineOrder order;
}

/// Archive or unarchive a collection (§3.4), then reload the home feed.
class SetArchivedEffect extends TimelineEffect {
  const SetArchivedEffect(this.collectionId, {required this.archived});
  final String collectionId;
  final bool archived;
}

/// Archive (or unarchive) an imported collection with the device-local flag
/// — it can't take a signed `archived_at` (docs/collection_share.md).
class SetLocalArchivedEffect extends TimelineEffect {
  const SetLocalArchivedEffect(this.collectionId, {required this.archived});
  final String collectionId;
  final bool archived;
}
