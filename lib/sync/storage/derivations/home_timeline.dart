/// The home timeline — spec §8.6.3. A per-collection read-time view, computed on
/// read for MVP (no cache table → no invalidation bugs). Never synced, never
/// signed.
///
/// Built as a pure function over the full projection ([buildHomeTimeline]), so it
/// is deterministic and testable without a live store. Display formatting (the
/// preview label, the relative time) stays in the UI: the read-models below carry
/// structured data only — a kind + text, never a pre-rendered string
/// (docs/architecture/widgets.md §1).
library;

import 'package:knit/sync/snapshot.dart';

/// The most-recently-added live card of a collection, as a preview (spec
/// §8.6.3). Carries the card [kind] and (for text cards) its [text]; the UI maps
/// a non-text kind to a summary like "Photo"/"Audio"/"Link".
class CardPreview {
  const CardPreview({
    required this.id,
    required this.kind,
    this.text,
    this.settled = false,
    this.linkTarget,
  });

  /// The card's id.
  final String id;

  /// `kind` — `text` | `image` | `audio` | `link` | … (spec §6.4).
  final String kind;

  /// `text` — the card body for a text card; null/absent for other kinds.
  final String? text;

  /// Whether the card is settled (spec §3.3); the row then shows it muted.
  final bool settled;

  /// What the card points at when it is a Connection card (§4.1/§4.2) whose
  /// target is live, so the row reads "→ Trips"; null otherwise. Not part of
  /// this derivation: the reader resolves it in a batched read and attaches it
  /// with [withLinkTarget].
  final LinkTargetPreview? linkTarget;

  factory CardPreview.of(Snapshot card) => CardPreview(
    id: card.id,
    kind: card.content['kind'] as String,
    text: card.content['text'] as String?,
    settled: card.content['settled_at'] != null,
  );

  /// This preview naming [target] as the Connection card's target.
  CardPreview withLinkTarget(LinkTargetPreview target) => CardPreview(
    id: id,
    kind: kind,
    text: text,
    settled: settled,
    linkTarget: target,
  );
}

/// The live target of a Connection card, as its preview names it (§4.1): a
/// collection by its title, or a card by its text, else its kind.
class LinkTargetPreview {
  const LinkTargetPreview({this.cardKind, this.name});

  /// The target card's `kind` tag; null when the target is a collection.
  final String? cardKind;

  /// The collection's title, or the card's text; null/blank when it has none.
  final String? name;
}

/// One row of the home timeline (spec §8.6.3) — a collection plus its derived
/// counters. Read-only; not a synced/signed entity.
class CollectionSummary {
  const CollectionSummary({
    required this.collectionId,
    required this.title,
    this.description,
    required this.coverAttachmentId,
    required this.cardCount,
    required this.lastCard,
    required this.lastUpdated,
    this.archived = false,
    this.createdBy = '',
  });

  /// This row with [lastCard] in place of its preview.
  CollectionSummary withLastCard(CardPreview lastCard) => CollectionSummary(
    collectionId: collectionId,
    title: title,
    description: description,
    coverAttachmentId: coverAttachmentId,
    cardCount: cardCount,
    lastCard: lastCard,
    lastUpdated: lastUpdated,
    archived: archived,
    createdBy: createdBy,
  );

  final String collectionId;
  final String title;

  /// The optional free-text blurb (spec §3.1); null when unset.
  final String? description;

  /// `cover_attachment_id` — nullable cover image (spec §6.4).
  final String? coverAttachmentId;

  /// Live card count: `COUNT(*) WHERE collection_id=:c AND deleted=0`.
  final int cardCount;

  /// Preview of the live card with the greatest `created_at`; null when empty.
  final CardPreview? lastCard;

  /// `MAX(created_at)` over live cards, else the collection's own `created_at`
  /// (spec §8.6.3). Drives the home sort (`last_updated DESC`).
  final int lastUpdated;

  /// Whether the collection is archived (spec §3.4): off the home timeline,
  /// listed on the Archive page instead.
  final bool archived;

  /// `created_by` — the creator's pubkey; another identity's collection is an
  /// imported, read-only one (docs/collection_share.md).
  final String createdBy;
}

/// Build the §8.6.3 home timeline from the full projection ([readAll] output):
/// one [CollectionSummary] per live collection, sorted `last_updated DESC`
/// (latest-updated first; ties broken by id for determinism). Tombstoned
/// collections and cards are excluded. Archived collections (§3.4) are kept and
/// flagged — the home screen sets them aside, other pickers still offer them.
///
/// > Flagged limitation (spec §8.6.3): `last_updated` tracks card *adds*, not
/// > edits — `created_at` is immutable and the HLC has no display duty, so
/// > editing a card does not resurface its collection. MVP-acceptable.
List<CollectionSummary> buildHomeTimeline(List<Snapshot> all) {
  final cardsByCollection = <String, List<Snapshot>>{};
  for (final s in all) {
    if (s.type == EntityType.card && !s.deleted) {
      (cardsByCollection[s.content['collection_id'] as String] ??= []).add(s);
    }
  }

  final summaries = [
    for (final s in all)
      if (s.type == EntityType.collection && !s.deleted)
        _summarize(s, cardsByCollection[s.id] ?? const []),
  ];

  summaries.sort((a, b) {
    final byUpdated = b.lastUpdated.compareTo(a.lastUpdated);
    return byUpdated != 0
        ? byUpdated
        : b.collectionId.compareTo(a.collectionId);
  });
  return summaries;
}

/// The card a collection's home-timeline row previews (spec §8.6.3): the
/// most-recently-added of [liveCards]. A `created_at` tie (same ms) goes to the
/// later HLC, then to the greater id, so the order is deterministic. Null when
/// there are none. Placement (`position`) plays no part, so a reorder never
/// changes it.
Snapshot? latestCard(Iterable<Snapshot> liveCards) {
  Snapshot? latest;
  for (final card in liveCards) {
    if (latest == null || _addedLater(card, latest)) latest = card;
  }
  return latest;
}

/// Whether [card] was added after [other]: a later `created_at`; on a tie, a
/// later HLC (back-to-back local creates in one ms still tick it, while their
/// UUIDv7 ids are random within the ms); on a tie of both, the greater id.
bool _addedLater(Snapshot card, Snapshot other) {
  final byCreated = card.createdAt.compareTo(other.createdAt);
  if (byCreated != 0) return byCreated > 0;
  final byHlc = card.hlc.compareTo(other.hlc);
  if (byHlc != 0) return byHlc > 0;
  return card.id.compareTo(other.id) > 0;
}

CollectionSummary _summarize(Snapshot collection, List<Snapshot> liveCards) {
  final lastCard = latestCard(liveCards);

  // MAX(created_at) over live cards, else the collection's own (spec §8.6.3).
  final lastUpdated = liveCards.isEmpty
      ? collection.createdAt
      : liveCards.map((c) => c.createdAt).reduce((a, b) => a > b ? a : b);

  return CollectionSummary(
    collectionId: collection.id,
    title: collection.content['title'] as String,
    description: collection.content['description'] as String?,
    coverAttachmentId: collection.content['cover_attachment_id'] as String?,
    cardCount: liveCards.length,
    lastCard: lastCard == null ? null : CardPreview.of(lastCard),
    lastUpdated: lastUpdated,
    archived: collection.content['archived_at'] != null,
    createdBy: collection.createdBy,
  );
}
