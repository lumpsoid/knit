/// Async-work descriptors for the Collection Media page (fcis.md §6.4).
sealed class CollectionMediaEffect {
  const CollectionMediaEffect();
}

/// Read [collectionId]'s media cards.
class LoadMediaEffect extends CollectionMediaEffect {
  const LoadMediaEffect(this.collectionId);
  final String collectionId;
}

/// Resolve the bytes of each photo in [attachmentIds] for its grid tile.
class LoadPhotoBytesEffect extends CollectionMediaEffect {
  const LoadPhotoBytesEffect(this.attachmentIds);
  final List<String> attachmentIds;
}

/// Share the file [attachmentId] through the system sheet under [fileName]
/// (falls back to a generic name when null), with its [caption] when set.
class ShareFileEffect extends CollectionMediaEffect {
  const ShareFileEffect({
    required this.attachmentId,
    this.fileName,
    this.caption,
  });
  final String attachmentId;
  final String? fileName;
  final String? caption;
}

/// Open [url] in the browser.
class OpenLinkEffect extends CollectionMediaEffect {
  const OpenLinkEffect(this.url);
  final String url;
}
