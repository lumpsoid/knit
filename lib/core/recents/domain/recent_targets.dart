import 'package:flutter/foundation.dart';

/// What a recents list remembers: one list per picker, so a move and a link
/// never crowd each other out.
enum RecentPurpose {
  /// Collections recently moved cards into (§4.2).
  move,

  /// Collections recently linked to (§4.4).
  link,
}

/// A most-recently-used list of collection ids (§4.2/§4.4), newest first —
/// what a picker offers at its top as "Recent". Device-local view state like
/// pins: never synced or signed. Pure; the storage only persists [ids].
@immutable
class RecentTargets {
  const RecentTargets([this.ids = const []]);

  /// How many ids are kept.
  static const int stored = 5;

  /// How many a picker shows.
  static const int shown = 3;

  /// The remembered ids, most recent first, without repeats.
  final List<String> ids;

  /// [id] was just used: it moves (or enters) to the front, and the list
  /// keeps at most [stored] ids.
  RecentTargets touched(String id) => RecentTargets(
    [
      id,
      ...ids.where((other) => other != id),
    ].take(stored).toList(growable: false),
  );

  /// The recents among [offered] — what the picker would offer anyway, so a
  /// deleted or excluded collection drops out — most recent first, at most
  /// [shown]. [idOf] reads an offered item's id.
  List<T> among<T>(Iterable<T> offered, String Function(T) idOf) {
    final byId = {for (final item in offered) idOf(item): item};
    return <T>[
      for (final id in ids) ?byId[id],
    ].take(shown).toList(growable: false);
  }
}
