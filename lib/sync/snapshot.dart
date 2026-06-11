/// The unit the merge-core operates on: a parsed, verified entity snapshot —
/// spec §6.3 (the envelope) + §6.4 (entity tables) + §7.4 (field sets).
///
/// Every synced op is a *full signed snapshot* of an entity (not a field delta) —
/// spec §6.6. After signature verification (out of scope for this sketch — it
/// happens upstream over `utf8(op.payload)`, spec §8.5 step 2), the payload JSON
/// is parsed into one of these and handed to the merge-core.
library;

import 'hlc.dart';

/// Entity kinds that ride the wire (spec §7.2 `entity_type`, authoritative as
/// `payload.t`). `attachment` syncs metadata only; bytes transfer out-of-band.
enum EntityType {
  collection,
  card,
  link,
  profile,
  attachment;

  /// Resolve an authoritative `payload.t` tag to its [EntityType].
  static EntityType fromTag(String t) {
    switch (t) {
      case 'collection':
        return EntityType.collection;
      case 'card':
        return EntityType.card;
      case 'link':
        return EntityType.link;
      case 'profile':
        return EntityType.profile;
      case 'attachment':
        return EntityType.attachment;
      default:
        throw ArgumentError('unknown entity type tag: $t');
    }
  }
}

/// A materialized entity snapshot — the envelope (spec §6.3) plus the
/// entity-specific content fields, plus (cards only) the *separate* placement
/// clock (spec §6.4 `position_*`).
///
/// This is both the wire payload shape and the projection-row shape; the merge
/// comparator and the projection store both speak [Snapshot].
class Snapshot {
  /// The fixed envelope + placement keys (spec §6.3 / §6.4); everything else in a
  /// payload is entity-specific [content].
  static const Set<String> _envelopeKeys = {
    't', 'id', 'author', 'created_by', 'created_at',
    'hlc_ms', 'hlc_counter', 'deleted', 'sig',
    'position', 'position_ms', 'position_counter',
  };

  // --- Envelope (spec §6.3) ---------------------------------------------------
  /// `payload.t` — the authoritative entity type.
  final EntityType type;

  /// `id` — UUIDv7 TEXT (for a profile: the pubkey hex).
  final String id;

  /// `author` — pubkey (hex) of whoever signed THIS version; `sig` verifies
  /// against it; the meaningful merge tiebreak (spec §6.9).
  final String author;

  /// `created_by` — original creator's pubkey; set once on create, copied
  /// forward verbatim on every edit, **never restamped** (spec §6.2). NOT a
  /// comparator input — it rides along like any content field.
  final String createdBy;

  /// `created_at` — immutable ms wall-clock, for display/sort only.
  final int createdAt;

  /// Content stamp `(hlc_ms, hlc_counter)` — last-write HLC, merge only.
  final Hlc hlc;

  /// `deleted` — soft tombstone (spec §6.1). Delete is a snapshot with
  /// `deleted=1`, not an unsigned op (spec §7.0).
  final bool deleted;

  /// `sig` — Ed25519 (hex) over the canonical payload bytes; the total-order
  /// backstop in the content comparator (spec §6.9).
  final String sig;

  // --- Placement clock (cards only — spec §6.4 / §8.4) ------------------------
  /// `(position_ms, position_counter)` — the *separate* reorder clock, or null
  /// for non-card entities. Kept distinct so a drag never clobbers a concurrent
  /// text edit (spec §7.6).
  final Hlc? placement;

  /// `position` — fractional-index string, compared **lexicographically by
  /// design** (the one intended string ordering; spec §8.5). Null for non-cards.
  final String? position;

  // --- Remaining entity-specific content fields -------------------------------
  /// Everything else from the payload (title, text, kind, source_id, …). Carried
  /// forward verbatim by the merge so the winning snapshot stays byte-faithful.
  final Map<String, Object?> content;

  const Snapshot({
    required this.type,
    required this.id,
    required this.author,
    required this.createdBy,
    required this.createdAt,
    required this.hlc,
    required this.deleted,
    required this.sig,
    this.placement,
    this.position,
    this.content = const {},
  }) : assert(
          (type == EntityType.card) == (placement != null),
          'cards carry a placement clock; non-cards must not',
        );

  bool get isCard => type == EntityType.card;

  /// The op's *observed clock* for device-clock advance — spec §8.2: the max
  /// over every stamp it carries. For a card that is max(content, placement)
  /// because a reorder's `position_*` can exceed its (frozen) `hlc_*`.
  Hlc get observedClock => placement == null ? hlc : Hlc.max(hlc, placement!);

  /// Produce the materialized card row when the *content* winner and the
  /// *placement* winner are different ops — spec §7.6 step 2. Takes this snapshot
  /// (the content winner) and overlays the placement winner's
  /// `position`/`position_ms`/`position_counter`. The `sig` stays the content
  /// winner's; the projection is a cache — verify via `change_log`, never against
  /// the blended row.
  Snapshot withPlacementFrom(Snapshot placementWinner) {
    assert(isCard && placementWinner.isCard, 'placement overlay is card-only');
    return Snapshot(
      type: type,
      id: id,
      author: author,
      createdBy: createdBy,
      createdAt: createdAt,
      hlc: hlc,
      deleted: deleted,
      sig: sig,
      placement: placementWinner.placement,
      position: placementWinner.position,
      content: content,
    );
  }

  /// A copy with selected fields replaced. Used by the write path to inject the
  /// `sig` once the canonical payload has been signed (§6.8). Nullable
  /// `placement`/`position` follow the standard keep-if-omitted rule, which is
  /// all the write path needs (cards always pass their placement explicitly).
  Snapshot copyWith({
    EntityType? type,
    String? id,
    String? author,
    String? createdBy,
    int? createdAt,
    Hlc? hlc,
    bool? deleted,
    String? sig,
    Hlc? placement,
    String? position,
    Map<String, Object?>? content,
  }) =>
      Snapshot(
        type: type ?? this.type,
        id: id ?? this.id,
        author: author ?? this.author,
        createdBy: createdBy ?? this.createdBy,
        createdAt: createdAt ?? this.createdAt,
        hlc: hlc ?? this.hlc,
        deleted: deleted ?? this.deleted,
        sig: sig ?? this.sig,
        placement: placement ?? this.placement,
        position: position ?? this.position,
        content: content ?? this.content,
      );

  /// Parse a verified canonical payload map (spec §7.4) into a [Snapshot].
  /// Pulls the fixed envelope + placement fields and bundles the rest into
  /// [content].
  factory Snapshot.fromPayload(Map<String, Object?> payload) {
    final type = EntityType.fromTag(payload['t'] as String);
    final isCard = type == EntityType.card;

    final content = <String, Object?>{
      for (final e in payload.entries)
        if (!_envelopeKeys.contains(e.key)) e.key: e.value,
    };

    return Snapshot(
      type: type,
      id: payload['id'] as String,
      author: payload['author'] as String,
      createdBy: payload['created_by'] as String,
      createdAt: payload['created_at'] as int,
      hlc: Hlc(payload['hlc_ms'] as int, payload['hlc_counter'] as int),
      // `deleted` is integer 0/1 on the wire (spec §7.1 rule 5).
      deleted: (payload['deleted'] as int) != 0,
      // `sig` lives in the op envelope, never in the signed payload (spec §7.2);
      // the apply path injects it here after verification.
      sig: payload['sig'] as String? ?? '',
      placement: isCard
          ? Hlc(payload['position_ms'] as int, payload['position_counter'] as int)
          : null,
      position: isCard ? payload['position'] as String : null,
      content: content,
    );
  }

  @override
  String toString() =>
      'Snapshot(${type.name} $id hlc=$hlc${isCard ? ' pos=$position@$placement' : ''}'
      '${deleted ? ' DELETED' : ''})';
}
