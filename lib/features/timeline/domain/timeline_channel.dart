import 'package:flutter/foundation.dart';

/// The Timeline feature's input channel (cross_feature.md §3): a feature-owned
/// event seam other features emit into when something they do changes what the
/// home timeline shows. The Timeline controller subscribes and folds events
/// into feature-owned Actions. This is *inbound intent into one feature*, not a
/// general pub/sub bus.
///
/// The channel splits into a sealed [TimelineChannelEvent] family and three
/// narrow halves — [TimelineChannelEmitter] (producer), [TimelineChannelReader]
/// (consumer: subscribe + read), and [TimelineChannelObserver] (the
/// subscribe-only subset) — so a producer never sees the observe side and the
/// consumer never sees the emit side.
sealed class TimelineChannelEvent {
  const TimelineChannelEvent();
}

/// Re-read the home feed. Emitted when something elsewhere (e.g. adding a card
/// in a collection, or renaming one) changes what the timeline renders —
/// last-updated, last-card previews, card counts, or a brand-new collection.
final class RefreshChannelEvent extends TimelineChannelEvent {
  const RefreshChannelEvent();
}

/// [collectionId] was deleted elsewhere (e.g. from its own Collection page):
/// re-read the home feed and drop the collection's pin.
final class CollectionDeletedChannelEvent extends TimelineChannelEvent {
  const CollectionDeletedChannelEvent(this.collectionId);
  final String collectionId;
}

/// Producer half — other features emit events here.
abstract interface class TimelineChannelEmitter {
  void emit(TimelineChannelEvent event);
}

/// Subscription half — (un)subscribe to emits. The narrow subset for code that
/// only needs to know *that* an event fired, not which.
abstract interface class TimelineChannelObserver {
  void addListener(VoidCallback listener);
  void removeListener(VoidCallback listener);
}

/// Consumer half — subscribe *and* read the latest event. The Timeline
/// controller holds this: it subscribes via [addListener], then reads
/// [latestEvent] on each notification to learn which event fired.
abstract interface class TimelineChannelReader
    implements TimelineChannelObserver {
  /// The most recent event pushed, or `null` before any emit.
  TimelineChannelEvent? get latestEvent;
}
