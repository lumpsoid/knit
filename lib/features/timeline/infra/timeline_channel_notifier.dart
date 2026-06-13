import 'package:flutter/foundation.dart';
import 'package:knit/features/timeline/domain/timeline_channel.dart';

/// In-memory [TimelineChannelEvent] channel (cross_feature.md §3), implementing
/// all three halves over a single [ChangeNotifier].
///
/// Backed by [ChangeNotifier] rather than [ValueNotifier] on purpose: every
/// [emit] must notify, but the channel's events are const-equal singletons
/// (`RefreshChannelEvent()`), and a [ValueNotifier] swallows a set to an equal
/// value — so two consecutive refreshes would deliver only one. [ChangeNotifier]
/// fires unconditionally; the latest event is held for [latestEvent].
class TimelineChannelNotifier extends ChangeNotifier
    implements TimelineChannelEmitter, TimelineChannelReader {
  TimelineChannelEvent? _latest;

  @override
  TimelineChannelEvent? get latestEvent => _latest;

  @override
  void emit(TimelineChannelEvent event) {
    _latest = event;
    notifyListeners();
  }
}
