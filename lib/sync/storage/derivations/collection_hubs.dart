/// Collection hubs — spec §8.6.4. A read-time derivation, never synced and
/// never signed: a collection that links to another one (from itself, or from
/// one of its cards) acts as a hub, tag or folder over it (§3). There is no
/// hierarchy in the model, only neutral links read this way.
///
/// Pure over the rows a batched backlink read returns ([buildCollectionHubs]),
/// so it is deterministic and testable without a live store.
library;

import 'package:knit/sync/snapshot.dart';

/// A live collection linking to another one — one name of a Home row's "in:"
/// line (§4.1). Primitives only.
class CollectionHub {
  const CollectionHub({required this.collectionId, required this.title});

  final String collectionId;
  final String title;

  @override
  bool operator ==(Object other) =>
      other is CollectionHub &&
      other.collectionId == collectionId &&
      other.title == title;

  @override
  int get hashCode => Object.hash(collectionId, title);

  @override
  String toString() => 'CollectionHub($collectionId, $title)';
}

/// The hubs over each of [collectionIds] (spec §8.6.4): the live collections
/// with a live link to it, made from the collection itself or from one of its
/// live cards. Each hub counts once however many links it holds; a collection
/// is never its own hub; a deleted source (card or collection) or a missing
/// one counts for nothing. An archived hub still counts (§3.4).
///
/// [links] are the live links pointing at [collectionIds] (other links are
/// ignored); [sourceCards] and [sourceCollections] are the rows of their
/// sources, and of the source cards' collections (tombstones included).
/// Hubs come sorted by title, case-insensitively, then id. Collections
/// without a hub are absent.
Map<String, List<CollectionHub>> buildCollectionHubs({
  required Iterable<String> collectionIds,
  required Iterable<Snapshot> links,
  required Iterable<Snapshot> sourceCards,
  required Iterable<Snapshot> sourceCollections,
}) {
  final targets = collectionIds.toSet();
  final cardCollection = {
    for (final card in sourceCards)
      if (!card.deleted) card.id: card.content['collection_id'] as String,
  };
  final live = {
    for (final c in sourceCollections)
      if (!c.deleted) c.id: c,
  };

  final hubIds = <String, Set<String>>{};
  for (final link in links) {
    final target = link.content['target_id'] as String?;
    if (link.deleted ||
        link.content['target_type'] != EntityType.collection.name ||
        !targets.contains(target)) {
      continue;
    }
    final source = link.content['source_id'] as String?;
    final hub = switch (link.content['source_type']) {
      'collection' => source,
      'card' => cardCollection[source],
      _ => null,
    };
    if (hub == null || hub == target || !live.containsKey(hub)) continue;
    (hubIds[target!] ??= {}).add(hub);
  }

  return {
    for (final MapEntry(key: target, value: ids) in hubIds.entries)
      target: [
        for (final id in ids)
          CollectionHub(
            collectionId: id,
            title: live[id]!.content['title'] as String? ?? '',
          ),
      ]..sort(_byTitle),
  };
}

int _byTitle(CollectionHub a, CollectionHub b) {
  final byTitle = a.title.toLowerCase().compareTo(b.title.toLowerCase());
  return byTitle != 0 ? byTitle : a.collectionId.compareTo(b.collectionId);
}
