import 'package:flutter/foundation.dart';
import 'package:knit/sync/sync.dart';

enum TimelineStatus { loading, ready, failed }

@immutable
class TimelineState {
  const TimelineState({
    this.status = TimelineStatus.loading,
    this.collections = const [],
  });

  final TimelineStatus status;
  final List<CollectionSummary> collections;

  bool get isEmpty => collections.isEmpty;

  TimelineState copyWith({
    TimelineStatus? status,
    List<CollectionSummary>? collections,
  }) =>
      TimelineState(
        status: status ?? this.status,
        collections: collections ?? this.collections,
      );
}
