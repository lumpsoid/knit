/// Merge-core — spec §6.9 (conflict rules) + §8.5 step 6 (merge comparators) +
/// §7.6 (reorder-vs-content blend) + §8.9 (rebuild-from-log).
///
/// No CRDT machinery: last-writer-wins + tombstones + two targeted per-field
/// clocks. Entirely client-side; the relay stays a pure router. The comparators
/// here are the *authoritative* ones (spec §8.5).
library;

import 'snapshot.dart';

/// Content comparator — spec §6.9 / §8.5. Higher
/// `(hlc_ms, hlc_counter, author, sig)` wins. `author` is the meaningful
/// tiebreak; `sig` is the total-order backstop (same keypair on two devices →
/// equal author, distinct sig). Integer/byte comparator — **never** string-sorted
/// on the HLC.
///
/// Returns >0 if [a] beats [b], <0 if [b] beats [a], 0 only when identical (a
/// true byte-identical resend → idempotent). `created_by` is deliberately NOT an
/// input: every honest version copies it unchanged, so the winner carries the
/// original creator's value regardless of who won (spec §6.9).
int compareContent(Snapshot a, Snapshot b) {
  final h = a.hlc.compareTo(b.hlc);
  if (h != 0) return h;
  // Pubkeys are lowercase ASCII hex, so code-unit order == byte order (spec §7.1).
  final author = a.author.compareTo(b.author);
  if (author != 0) return author;
  return a.sig.compareTo(b.sig);
}

/// Placement comparator (cards only) — spec §8.5. Higher
/// `(position_ms, position_counter, position)` wins; `position` (fractional-index
/// string) is compared **lexicographically by design** — the one intended string
/// ordering (the HLC is not). A drag never clobbers a concurrent text edit
/// because placement has its own clock (spec §7.6).
int comparePlacement(Snapshot a, Snapshot b) {
  assert(a.isCard && b.isCard, 'placement comparison is card-only');
  final p = a.placement!.compareTo(b.placement!);
  if (p != 0) return p;
  return a.position!.compareTo(b.position!);
}

/// Merge an [incoming] snapshot against the [current] projection row, returning
/// the new projection row — spec §8.5 step 6.
///
/// - First write for an id → take it.
/// - Content dimension: keep the [compareContent] winner. This also covers
///   delete-vs-edit — a delete is just a snapshot with `deleted=1` and a higher
///   HLC, so a *late edit can resurrect* (spec §6.9 / §8.5).
/// - Cards only: overlay the [comparePlacement] winner's position onto the
///   content winner (spec §7.6). When both winners are the same op, no overlay.
///
/// Ties (comparator == 0) keep [current]: a true resend is byte-identical, so the
/// projection is unchanged — idempotent.
Snapshot merge(Snapshot? current, Snapshot incoming) {
  if (current == null) return incoming;
  assert(current.id == incoming.id, 'merge is per-entity (same id)');

  final contentWinner = compareContent(incoming, current) > 0
      ? incoming
      : current;

  if (!incoming.isCard) return contentWinner;

  final placementWinner = comparePlacement(incoming, current) > 0
      ? incoming
      : current;

  if (identical(placementWinner, contentWinner)) return contentWinner;
  return contentWinner.withPlacementFrom(placementWinner);
}

/// The materialized entity projection — spec §6.8 ("a fast projection") / §8.9
/// ("a disposable projection of `change_log`").
///
/// Holds the merged latest-winner snapshot per id. Replaying `change_log` in
/// `seq ASC` through [apply] yields the identical projection regardless of
/// arrival order — that order-independence *is* local-first (spec §8.9). This
/// store is in-memory; production materializes the same result into sqflite tables.
class Projection {
  final Map<String, Snapshot> _rows = {};

  /// The current row for [id], or null if never seen.
  Snapshot? operator [](String id) => _rows[id];

  /// All current rows (tombstones included — read-time queries filter `deleted`).
  Iterable<Snapshot> get rows => _rows.values;

  int get length => _rows.length;

  /// Merge one op into the projection (spec §8.5 step 6). Idempotent and
  /// order-independent under the comparators above.
  Snapshot apply(Snapshot op) => _rows[op.id] = merge(_rows[op.id], op);

  /// Rebuild from a `change_log` already ordered by `seq ASC` — spec §8.9 step 2.
  /// Merge-core only: no re-verify, no clock advance, no new log insert.
  void replay(Iterable<Snapshot> opsInSeqOrder) {
    for (final op in opsInSeqOrder) {
      apply(op);
    }
  }

  /// Live cards in a collection, in feed order — spec §8.7. `position` is
  /// lexicographic by design; `id` (UUIDv7) is the deterministic tiebreak when
  /// concurrent inserts into one gap mint identical positions on different cards.
  List<Snapshot> feed(String collectionId) {
    final cards = _rows.values.where(
      (s) =>
          s.isCard && !s.deleted && s.content['collection_id'] == collectionId,
    );
    final sorted = cards.toList()
      ..sort((a, b) {
        final p = a.position!.compareTo(b.position!);
        return p != 0 ? p : a.id.compareTo(b.id);
      });
    return sorted;
  }
}
