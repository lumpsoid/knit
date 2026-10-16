/// Async-work descriptors for the Collection Media page (fcis.md §6.4).
sealed class CollectionMediaEffect {
  const CollectionMediaEffect();
}

/// Read [collectionId]'s media cards.
class LoadMediaEffect extends CollectionMediaEffect {
  const LoadMediaEffect(this.collectionId);
  final String collectionId;
}

/// The grid shows the photos [attachmentIds]: hand them to the shared image
/// cache, which loads any it doesn't hold yet.
class ShowPhotosEffect extends CollectionMediaEffect {
  const ShowPhotosEffect(this.attachmentIds);
  final List<String> attachmentIds;
}

/// The page left: let the shared image cache drop its photos.
class ReleasePhotosEffect extends CollectionMediaEffect {
  const ReleasePhotosEffect();
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
