import 'package:flutter/foundation.dart';
import 'package:knit/sync/sync.dart';

enum TimelineStatus { loading, ready, failed }

@immutable
class TimelineState {
  const TimelineState({
    this.status = TimelineStatus.loading,
    this.collections = const [],
    this.coverBytes = const {},
  });

  final TimelineStatus status;
  final List<CollectionSummary> collections;

  /// Decoded bytes of collection cover images, keyed by `attachment_id`.
  /// Content-addressed, so an id's bytes are immutable — cached here to avoid
  /// reloading on every feed refresh. Absent ⇒ loading or missing, which
  /// renders the lettered-avatar placeholder fallback.
  final Map<String, Uint8List> coverBytes;

  bool get isEmpty => collections.isEmpty;

  TimelineState copyWith({
    TimelineStatus? status,
    List<CollectionSummary>? collections,
    Map<String, Uint8List>? coverBytes,
  }) => TimelineState(
    status: status ?? this.status,
    collections: collections ?? this.collections,
    coverBytes: coverBytes ?? this.coverBytes,
  );
}
