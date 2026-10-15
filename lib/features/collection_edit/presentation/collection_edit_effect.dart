/// Async-work descriptors for the Collection Edit page (fcis.md §6.4).
sealed class CollectionEditEffect {
  const CollectionEditEffect();
}

/// Persist the collection's title + description (spec §3.1/§7.4). [title] is the
/// trimmed, non-blank name; [description] is the trimmed blurb or null.
class SaveDetailsEffect extends CollectionEditEffect {
  const SaveDetailsEffect({
    required this.collectionId,
    required this.title,
    this.description,
  });
  final String collectionId;
  final String title;
  final String? description;
}

/// Load the decoded bytes for the cover [attachmentId] to render the current
/// cover image.
class LoadCoverEffect extends CollectionEditEffect {
  const LoadCoverEffect(this.attachmentId);
  final String attachmentId;
}

/// Load [collectionId]'s media summary (counts + newest photo thumbnails).
class LoadMediaSummaryEffect extends CollectionEditEffect {
  const LoadMediaSummaryEffect(this.collectionId);
  final String collectionId;
}

/// Pick a photo (gallery/camera), store it, point [collectionId] at the new
/// cover, and GC the [previousAttachmentId] it replaced (if any).
class PickCoverEffect extends CollectionEditEffect {
  const PickCoverEffect({
    required this.collectionId,
    required this.previousAttachmentId,
  });
  final String collectionId;
  final String? previousAttachmentId;
}

/// Clear [collectionId]'s cover and GC the [previousAttachmentId].
class RemoveCoverEffect extends CollectionEditEffect {
  const RemoveCoverEffect({
    required this.collectionId,
    required this.previousAttachmentId,
  });
  final String collectionId;
  final String? previousAttachmentId;
}
