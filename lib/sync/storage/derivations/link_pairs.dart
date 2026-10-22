/// One link per pair — spec §6.4. A read-time derivation, never synced and
/// never signed: two live links joining the same source to the same target
/// say the same thing (the `label` aside), so every read treats them as one.
/// Duplicates still happen — each link has its own id, so two devices linking
/// the same pair concurrently, or data from before the rule, leave two rows —
/// and the oldest one stands for the pair.
///
/// Pure over link rows, so it is deterministic and testable without a store.
library;

import 'package:knit/sync/snapshot.dart';

/// The (source, target) a link joins — its identity for reads (§6.4). The
/// `label` is not part of it.
class LinkPair {
  const LinkPair({
    required this.sourceType,
    required this.sourceId,
    required this.targetType,
    required this.targetId,
  });

  /// The pair [link] joins.
  factory LinkPair.of(Snapshot link) => LinkPair(
    sourceType: link.content['source_type'] as String? ?? '',
    sourceId: link.content['source_id'] as String? ?? '',
    targetType: link.content['target_type'] as String? ?? '',
    targetId: link.content['target_id'] as String? ?? '',
  );

  final String sourceType;
  final String sourceId;
  final String targetType;
  final String targetId;

  @override
  bool operator ==(Object other) =>
      other is LinkPair &&
      other.sourceType == sourceType &&
      other.sourceId == sourceId &&
      other.targetType == targetType &&
      other.targetId == targetId;

  @override
  int get hashCode => Object.hash(sourceType, sourceId, targetType, targetId);

  @override
  String toString() =>
      'LinkPair($sourceType:$sourceId → $targetType:$targetId)';
}

/// Whether links [a] and [b] are duplicates: the same source and the same
/// target, whatever their labels (§6.4).
bool isDuplicateLink(Snapshot a, Snapshot b) =>
    LinkPair.of(a) == LinkPair.of(b);

/// The live [links] with one row per pair (§6.4): of duplicates, the oldest
/// stands (earliest `created_at`, then the smaller id, so every device keeps
/// the same one). Tombstones are dropped; the survivors keep their input
/// order, and a row passed twice counts once.
List<Snapshot> distinctLinks(Iterable<Snapshot> links) {
  final keep = <LinkPair, Snapshot>{};
  for (final link in links) {
    if (link.deleted) continue;
    final pair = LinkPair.of(link);
    final kept = keep[pair];
    if (kept == null || _older(link, kept)) keep[pair] = link;
  }
  final kept = {for (final link in keep.values) link.id};
  final seen = <String>{};
  return [
    for (final link in links)
      if (kept.contains(link.id) && seen.add(link.id)) link,
  ];
}

/// For each of [entityIds], how many distinct live links it takes part in —
/// links-out plus backlinks, a pair counted once (§6.4). Ids with no live link
/// are absent (read as zero).
Map<String, int> countLinks(
  Iterable<Snapshot> links,
  Iterable<String> entityIds,
) {
  final wanted = entityIds.toSet();
  final counts = <String, int>{};
  void bump(Object? id) {
    if (id is String && wanted.contains(id)) {
      counts[id] = (counts[id] ?? 0) + 1;
    }
  }

  for (final link in distinctLinks(links)) {
    bump(link.content['source_id']);
    bump(link.content['target_id']);
  }
  return counts;
}

/// For each of [entityIds], how many distinct live links point *at* it — its
/// backlinks, a pair counted once (§6.4). Ids with none are absent (zero).
Map<String, int> countBacklinks(
  Iterable<Snapshot> links,
  Iterable<String> entityIds,
) {
  final wanted = entityIds.toSet();
  final counts = <String, int>{};
  for (final link in distinctLinks(links)) {
    final id = link.content['target_id'];
    if (id is String && wanted.contains(id)) {
      counts[id] = (counts[id] ?? 0) + 1;
    }
  }
  return counts;
}

bool _older(Snapshot a, Snapshot b) => a.createdAt != b.createdAt
    ? a.createdAt < b.createdAt
    : a.id.compareTo(b.id) < 0;
