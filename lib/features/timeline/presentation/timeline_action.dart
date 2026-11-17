import 'package:knit/features/timeline/domain/timeline_order.dart';
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
  const CollectionsLoaded(
    this.collections, {
    this.pinnedIds,
    this.importedOwners = const {},
    this.localArchivedIds,
    this.hubs = const {},
    this.order,
  });
  final List<CollectionSummary> collections;
  final Set<String>? pinnedIds;

  /// The imported collections' creator handles, by collection id.
  final Map<String, String> importedOwners;

  /// The locally archived (imported) collections; null keeps the last known.
  final Set<String>? localArchivedIds;

  /// The hubs over each collection (§8.6.4), for the rows' "in:" line.
  final Map<String, List<CollectionHub>> hubs;

  /// The device-local manual order; null keeps the last known.
  final TimelineOrder? order;
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

/// Long-press → Reorder on the Home sheet: enter drag-to-reorder mode.
class ReorderStarted extends TimelineAction {
  const ReorderStarted();
}

/// Done in reorder mode: leave drag-to-reorder mode.
class ReorderEnded extends TimelineAction {
  const ReorderEnded();
}

/// A reorder-mode drag over the flat `[...pinned, ...others]` list, with
/// `onReorderItem` semantics (the drop index is the final slot).
class CollectionMoved extends TimelineAction {
  const CollectionMoved(this.oldIndex, this.newIndex);
  final int oldIndex;
  final int newIndex;
}

/// "Reset to recent" in reorder mode: clear the manual order.
class OrderResetRequested extends TimelineAction {
  const OrderResetRequested();
}

/// The manual order was persisted; [order] is the order after the write.
class OrderChanged extends TimelineAction {
  const OrderChanged(this.order);
  final TimelineOrder order;
}

/// Saving the manual order failed; the dragged order stays on screen.
class OrderUpdateFailed extends TimelineAction {
  const OrderUpdateFailed();
}

/// Long-press → Archive / Unarchive on a collection row (§3.4, synced).
class ArchiveToggled extends TimelineAction {
  const ArchiveToggled(this.collectionId, {required this.archived});
  final String collectionId;

  /// The desired state: true archives, false unarchives.
  final bool archived;
}

/// A collection was archived or unarchived → the home feed re-reads itself.
class CollectionArchiveChanged extends TimelineAction {
  const CollectionArchiveChanged(this.collectionId, {required this.archived});
  final String collectionId;
  final bool archived;
}

class ArchiveUpdateFailed extends TimelineAction {
  const ArchiveUpdateFailed();
}

class DeactivateFeature extends TimelineAction {
  const DeactivateFeature();
}
