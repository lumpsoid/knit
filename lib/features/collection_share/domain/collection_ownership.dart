/// Whose a collection is (docs/collection_share.md "Read-only"): derived on
/// read from its `created_by`, so no table holds it and a future relay
/// subscription behaves the same. The one place keys are compared — the
/// controllers ask this, no widget does.
enum CollectionOwnership {
  /// Created by this device's identity: fully editable.
  own,

  /// Created by someone else (imported from a share file): read-only.
  imported;

  static CollectionOwnership of(String createdBy, String me) =>
      createdBy == me ? own : imported;

  /// Cards, header and placement may be written.
  bool get canEdit => this == own;
}

/// How archiving a collection is stored: a signed `archived_at` on an own
/// collection, a device-local flag on an imported one (like pins).
enum ArchiveTarget {
  signed,
  local;

  static ArchiveTarget of(CollectionOwnership ownership) =>
      ownership.canEdit ? signed : local;
}
