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

/// The cover section shows [attachmentId] (null = no cover): hand it to the
/// shared image cache, which loads it if it isn't held yet.
class ShowCoverEffect extends CollectionEditEffect {
  const ShowCoverEffect(this.attachmentId);
  final String? attachmentId;
}

/// The page left: let the shared image cache drop its cover + previews.
class ReleaseImagesEffect extends CollectionEditEffect {
  const ReleaseImagesEffect();
}

/// Load [collectionId]'s media summary (counts + newest photo thumbnails).
class LoadMediaSummaryEffect extends CollectionEditEffect {
  const LoadMediaSummaryEffect(this.collectionId);
  final String collectionId;
}

/// Pick a photo (gallery/camera), store it, and point [collectionId] at the new
/// cover (the shared details reclaim the one it replaced).
class PickCoverEffect extends CollectionEditEffect {
  const PickCoverEffect(this.collectionId);
  final String collectionId;
}

/// Clear [collectionId]'s cover (the shared details reclaim the image).
class RemoveCoverEffect extends CollectionEditEffect {
  const RemoveCoverEffect(this.collectionId);
  final String collectionId;
}
