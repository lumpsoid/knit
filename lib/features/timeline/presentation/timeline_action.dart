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

class CollectionsLoaded extends TimelineAction {
  const CollectionsLoaded(this.collections);
  final List<CollectionSummary> collections;
}

class TimelineLoadFailed extends TimelineAction {
  const TimelineLoadFailed(this.message);
  final String message;
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
  const CollectionCreateFailed(this.message);
  final String message;
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
  const CollectionDeleteFailed(this.message);
  final String message;
}

class DeactivateFeature extends TimelineAction {
  const DeactivateFeature();
}
