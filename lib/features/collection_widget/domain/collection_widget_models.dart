import 'package:flutter/foundation.dart';

/// A placed home-screen widget and the collection it is bound to — null until
/// one is picked.
@immutable
class CollectionWidgetBinding {
  const CollectionWidgetBinding({required this.widgetId, this.collectionId});

  final int widgetId;
  final String? collectionId;
}

/// What one bound widget shows: its collection's current [title], or — when
/// the collection was deleted — the [removed] state (no title). A live tile
/// offers the ✎ [quickInput] unless its collection is an imported, read-only
/// one (docs/collection_share.md).
@immutable
class CollectionWidgetTile {
  const CollectionWidgetTile.live({
    required this.widgetId,
    required this.title,
    this.quickInput = true,
  }) : removed = false;

  const CollectionWidgetTile.removed({required this.widgetId})
    : title = null,
      removed = true,
      quickInput = false;

  final int widgetId;
  final String? title;
  final bool removed;
  final bool quickInput;

  @override
  bool operator ==(Object other) =>
      other is CollectionWidgetTile &&
      other.widgetId == widgetId &&
      other.title == title &&
      other.removed == removed &&
      other.quickInput == quickInput;

  @override
  int get hashCode => Object.hash(widgetId, title, removed, quickInput);
}

/// A collection a widget can be bound to — a row of the picker.
@immutable
class CollectionWidgetTarget {
  const CollectionWidgetTarget({
    required this.collectionId,
    required this.title,
  });

  final String collectionId;
  final String title;

  /// Whether this row survives the picker's filter [query]: a case-insensitive
  /// substring of the title. A blank query keeps every row.
  bool matches(String query) {
    final q = query.trim().toLowerCase();
    return q.isEmpty || title.toLowerCase().contains(q);
  }
}
