import 'package:knit/sync/sync.dart';

/// Intents + async-result deliveries for Timeline (fcis.md §6.4).
sealed class TimelineAction {
  const TimelineAction();
}

class ViewAttached extends TimelineAction {
  const ViewAttached();
}

class RefreshRequested extends TimelineAction {
  const RefreshRequested();
}

/// The home feed loaded, together with this device's pinned ids so the Pinned
/// section renders in the same frame as the list. [pinnedIds] is null when the
/// pin store couldn't be read — the previously known pins are kept.
class CollectionsLoaded extends TimelineAction {
  const CollectionsLoaded(this.collections, {this.pinnedIds});
  final List<CollectionSummary> collections;
  final Set<String>? pinnedIds;
}

class TimelineLoadFailed extends TimelineAction {
  const TimelineLoadFailed();
}

/// Tapped an existing collection row → open the Collection screen (§4.1).
class CollectionTapped extends TimelineAction {
  const CollectionTapped(this.collectionId);
  final String collectionId;
}

/// Inline create submitted a title/theme line (§4.1).
class CreateCollectionRequested extends TimelineAction {
  const CreateCollectionRequested(this.title);
  final String title;
}

/// A new collection persisted → open it with the composer ready (§4.1).
class CollectionCreated extends TimelineAction {
  const CollectionCreated(this.collectionId);
  final String collectionId;
}

class CollectionCreateFailed extends TimelineAction {
  const CollectionCreateFailed();
}

/// Long-press → Delete confirmed for an existing collection row (§4.1).
class DeleteCollectionRequested extends TimelineAction {
  const DeleteCollectionRequested(this.collectionId);
  final String collectionId;
}

/// A collection was deleted → the home feed re-reads itself.
class CollectionDeleted extends TimelineAction {
  const CollectionDeleted(this.collectionId);
  final String collectionId;
}

class CollectionDeleteFailed extends TimelineAction {
  const CollectionDeleteFailed();
}

/// Long-press → Pin / Unpin on a collection row (§4.1, device-local).
class PinToggled extends TimelineAction {
  const PinToggled(this.collectionId, {required this.pinned});
  final String collectionId;

  /// The desired state: true pins, false unpins.
  final bool pinned;
}

/// The pinned set was persisted; [pinnedIds] is the full set after the write.
class PinsChanged extends TimelineAction {
  const PinsChanged(this.pinnedIds);
  final Set<String> pinnedIds;
}

class PinUpdateFailed extends TimelineAction {
  const PinUpdateFailed();
}

class DeactivateFeature extends TimelineAction {
  const DeactivateFeature();
}
