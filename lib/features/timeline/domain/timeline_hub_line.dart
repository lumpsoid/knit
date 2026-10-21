import 'package:flutter/foundation.dart';

/// A home row's "in:" line (§4.1): the first [maxShown] hub names, and how
/// many more there are. Pure; the row formats it ("in: House · Trips +1").
@immutable
class TimelineHubLine {
  const TimelineHubLine({required this.names, this.more = 0});

  /// The line for [names] (already in hub order), or null when there are
  /// none — the row then shows no line.
  static TimelineHubLine? of(List<String> names) {
    if (names.isEmpty) return null;
    return TimelineHubLine(
      names: names.take(maxShown).toList(growable: false),
      more: names.length > maxShown ? names.length - maxShown : 0,
    );
  }

  /// How many hub names a row spells out.
  static const int maxShown = 2;

  final List<String> names;

  /// The hubs beyond [names]; zero shows no "+N".
  final int more;

  @override
  bool operator ==(Object other) =>
      other is TimelineHubLine &&
      listEquals(other.names, names) &&
      other.more == more;

  @override
  int get hashCode => Object.hash(Object.hashAll(names), more);
}
