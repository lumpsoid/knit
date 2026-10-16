import 'package:flutter/foundation.dart';

/// A collection's editable header (spec §3.1): its [title], optional
/// [description] and optional cover image (`cover_attachment_id`, §7.4.1). The
/// one copy the Timeline, the Collection screen and the Collection Edit page all
/// read — primitives only (widgets.md §1), no sync-core type.
@immutable
class CollectionDetails {
  const CollectionDetails({
    required this.collectionId,
    required this.title,
    this.description,
    this.coverAttachmentId,
  });

  final String collectionId;
  final String title;

  /// The optional free-text blurb; null when unset.
  final String? description;

  /// The cover image's attachment id; null when the collection has no cover.
  final String? coverAttachmentId;

  bool get hasCover => coverAttachmentId != null;

  static const Object _unset = Object();

  /// Copy with the given fields changed. [description] and [coverAttachmentId]
  /// take an explicit null to clear them (the `?? this` idiom can't).
  CollectionDetails copyWith({
    String? title,
    Object? description = _unset,
    Object? coverAttachmentId = _unset,
  }) => CollectionDetails(
    collectionId: collectionId,
    title: title ?? this.title,
    description: description == _unset
        ? this.description
        : description as String?,
    coverAttachmentId: coverAttachmentId == _unset
        ? this.coverAttachmentId
        : coverAttachmentId as String?,
  );

  @override
  bool operator ==(Object other) =>
      other is CollectionDetails &&
      other.collectionId == collectionId &&
      other.title == title &&
      other.description == description &&
      other.coverAttachmentId == coverAttachmentId;

  @override
  int get hashCode =>
      Object.hash(collectionId, title, description, coverAttachmentId);
}
