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

class DeactivateFeature extends TimelineAction {
  const DeactivateFeature();
}
