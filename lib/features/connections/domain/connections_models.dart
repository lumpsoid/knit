/// View-models for the Connections view (§4.4). Primitives only — never a
/// `Snapshot` or other sync-core type (widgets.md §1) — so the presentation
/// layer and shared widgets never reach into the merge core.
library;

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
}
