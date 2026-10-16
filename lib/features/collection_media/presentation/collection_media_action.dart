import 'package:knit/features/collection_media/domain/collection_media_models.dart';

/// Intents + async-result deliveries for the Collection Media page (fcis.md
/// §6.4).
sealed class CollectionMediaAction {
  const CollectionMediaAction();
}

/// View attached for [collectionId] (from the route-args carrier,
/// cross_feature.md §2). Starts a fresh load.
class ViewAttached extends CollectionMediaAction {
  const ViewAttached({required this.collectionId});
  final String collectionId;
}

/// Re-read the media — on retry, or after returning from the Card Edit page.
class ReloadRequested extends CollectionMediaAction {
  const ReloadRequested();
}

class MediaLoaded extends CollectionMediaAction {
  const MediaLoaded(this.media);
  final CollectionMedia media;
}

class MediaLoadFailed extends CollectionMediaAction {
  const MediaLoadFailed();
}

/// A file item tapped — hand it to the system share sheet ("Open with…").
class FileShareRequested extends CollectionMediaAction {
  const FileShareRequested(this.cardId);
  final String cardId;
}

/// A link item tapped — open its URL in the browser.
class LinkOpenRequested extends CollectionMediaAction {
  const LinkOpenRequested(this.cardId);
  final String cardId;
}

class DeactivateFeature extends CollectionMediaAction {
  const DeactivateFeature();
}
