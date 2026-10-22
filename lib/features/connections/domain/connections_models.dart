/// View-models for the Connections view (§4.4). Primitives only — never a
/// `Snapshot` or other sync-core type (widgets.md §1) — so the presentation
/// layer and shared widgets never reach into the merge core.
library;

import 'package:flutter/foundation.dart';

/// The kind of entity a connection touches (spec §4.4). Presentation-level
/// mirror of the sync-core `EntityType`, kept primitive so the UI never imports
/// the merge core. Only collections and cards participate as link endpoints in
/// the MVP; an unknown tag (a newer peer's endpoint kind) degrades rather than
/// throwing, exactly like a card `kind`.
enum ConnectedEntityKind {
  collection,
  card,
  unknown;

  /// The stored `*_type` tag on a link (spec §7.4 — the sync-core enum name).
  String get tag => this == ConnectedEntityKind.unknown ? 'collection' : name;

  static ConnectedEntityKind fromTag(String? tag) => switch (tag) {
    'collection' => ConnectedEntityKind.collection,
    'card' => ConnectedEntityKind.card,
    _ => ConnectedEntityKind.unknown,
  };
}

/// Which way a link points relative to the focused entity (spec §4.4):
/// [outgoing] = a link this entity is the source of (links-out); [incoming] =
/// a link this entity is the target of (linked-from / backlink, §8.6.2).
enum ConnectionDirection { outgoing, incoming }

/// One connection in the §4.4 view: the *other* endpoint of a link touching the
/// focused entity, plus its liveness. [broken] drives the §8.6.1 chip — a broken
/// connection is always shown (never hidden) and is not tappable-to-jump; it
/// offers clear instead. The link itself is never auto-deleted (§8.6.1).
class ConnectionItem {
  const ConnectionItem({
    required this.linkId,
    required this.direction,
    required this.otherKind,
    required this.otherId,
    required this.broken,
    this.label,
    this.openCollectionId,
    this.ownSource = false,
  });

  /// The `link` entity id — the handle the "clear" action removes.
  final String linkId;
  final ConnectionDirection direction;

  /// The endpoint at the *far* end of the link (the one a jump navigates to).
  final ConnectedEntityKind otherKind;
  final String otherId;

  /// The far endpoint is missing or tombstoned (§8.6.1/§8.6.2) → render broken.
  final bool broken;

  /// Title (collection) or text preview (card) of the far endpoint; null when
  /// it is broken (missing/tombstoned).
  final String? label;

  /// The collection to open so the far endpoint can be seen *inside* it (§4.2):
  /// for a collection endpoint, the endpoint itself; for a card endpoint, the
  /// collection that holds it. Null when it can't be resolved (broken, or an
  /// unknown endpoint kind) — the View then shows no "open" affordance.
  final String? openCollectionId;

  /// The link's source is this identity's own — an own collection, or a card
  /// in one (`CollectionOwnership`) — so its link may be removed. Never for
  /// an imported, read-only source; read for a live link only (false when
  /// [broken]).
  final bool ownSource;

  /// Whether the row offers Remove (§4.4): a live link from an own source. A
  /// broken one offers the §8.6.1 clear instead.
  bool get removable => ownSource && !broken;
}

/// The two ends of a link — what an Undo re-links after a Remove (§4.4).
@immutable
class LinkEnds {
  const LinkEnds({
    required this.sourceKind,
    required this.sourceId,
    required this.targetKind,
    required this.targetId,
  });

  final ConnectedEntityKind sourceKind;
  final String sourceId;
  final ConnectedEntityKind targetKind;
  final String targetId;

  @override
  bool operator ==(Object other) =>
      other is LinkEnds &&
      other.sourceKind == sourceKind &&
      other.sourceId == sourceId &&
      other.targetKind == targetKind &&
      other.targetId == targetId;

  @override
  int get hashCode => Object.hash(sourceKind, sourceId, targetKind, targetId);
}

/// A breadcrumb entry — one hop in the §4.4 back-stack so deep wandering doesn't
/// lose you. The page renders the trail; tapping a crumb jumps back to it.
class ConnectionCrumb {
  const ConnectionCrumb({
    required this.kind,
    required this.id,
    required this.title,
  });

  final ConnectedEntityKind kind;
  final String id;
  final String title;
}

/// The full Connections payload for one focused entity (spec §4.4): its
/// links-out and linked-from (backlinks), read together so the View never
/// issues a second load.
class ConnectionsData {
  const ConnectionsData({
    required this.focusKind,
    required this.focusId,
    required this.focusTitle,
    required this.outgoing,
    required this.incoming,
  });

  final ConnectedEntityKind focusKind;
  final String focusId;
  final String focusTitle;

  /// Links this entity is the source of (links-out).
  final List<ConnectionItem> outgoing;

  /// Links this entity is the target of (backlinks, §8.6.2).
  final List<ConnectionItem> incoming;

  bool get isEmpty => outgoing.isEmpty && incoming.isEmpty;

  /// The ends of [item]'s link: the focus is its source for a link out, its
  /// target for a backlink (§8.6.2).
  LinkEnds endsOf(ConnectionItem item) => switch (item.direction) {
    ConnectionDirection.outgoing => LinkEnds(
      sourceKind: focusKind,
      sourceId: focusId,
      targetKind: item.otherKind,
      targetId: item.otherId,
    ),
    ConnectionDirection.incoming => LinkEnds(
      sourceKind: item.otherKind,
      sourceId: item.otherId,
      targetKind: focusKind,
      targetId: focusId,
    ),
  };
}
