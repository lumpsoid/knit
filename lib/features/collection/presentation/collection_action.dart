import 'dart:typed_data';

import 'package:knit/core/attachments/domain/picked_image.dart';
import 'package:knit/features/collection/domain/collection_models.dart';
import 'package:knit/features/connections/domain/connections_models.dart';

/// Intents + async-result deliveries for the Collection screen (fcis.md §6.4).
/// All payloads are scalars / feature-local view-models (no sync-core types).
sealed class CollectionAction {
  const CollectionAction();
}

/// View attached for [collectionId] (read from the route-args carrier, §2).
class ViewAttached extends CollectionAction {
  const ViewAttached(this.collectionId);
  final String collectionId;
}

/// Re-read the feed silently (pull-to-refresh and post-write resync).
class ReloadRequested extends CollectionAction {
  const ReloadRequested();
}

class CollectionLoaded extends CollectionAction {
  const CollectionLoaded(this.data);
  final CollectionData data;
}

class LoadFailed extends CollectionAction {
  const LoadFailed();
}

/// An image card's decoded bytes finished loading. [bytes] is null when the
/// attachment is missing/unreadable — the placeholder stays and nothing caches.
class ImageBytesLoaded extends CollectionAction {
  const ImageBytesLoaded(this.attachmentId, this.bytes);
  final String attachmentId;
  final Uint8List? bytes;
}

/// Bottom composer submitted a quick text card (§4.2).
class ComposerSubmitted extends CollectionAction {
  const ComposerSubmitted(this.text);
  final String text;
}

/// The "+" add-block finder submitted a standalone link card (§4.2).
class LinkCardSubmitted extends CollectionAction {
  const LinkCardSubmitted(this.url);
  final String url;
}

/// The "+" add-block finder chose Photo (§4.2): open the picker so the chosen
/// image can be previewed above the composer before it becomes a card.
class PickImageRequested extends CollectionAction {
  const PickImageRequested();
}

/// Delivery of [PickImageRequested]: the picker returned [image] (null when the
/// user cancelled). A non-null image becomes the composer's pending preview.
class ImagePicked extends CollectionAction {
  const ImagePicked(this.image);
  final PickedImage? image;
}

/// The preview's clear ("✕") button — drop the pending image without writing
/// anything. The user can then send text only, or pick a different image.
class PendingImageCleared extends CollectionAction {
  const PendingImageCleared();
}

/// Actions sheet → delete a card (§4.2). Links to it become broken, not gone.
class CardDeleteRequested extends CollectionAction {
  const CardDeleteRequested(this.cardId);
  final String cardId;
}

/// Actions sheet → "Make a link" opened the finder (§4.4). Loads the first
/// level (collections); a no-op if they are already loaded is fine — it just
/// refreshes them.
class LinkFinderOpened extends CollectionAction {
  const LinkFinderOpened();
}

/// Finder drilled into [collectionId] to browse its cards. Triggers a lazy
/// card load on cache miss; a cache hit is a pure no-op.
class LinkCollectionOpened extends CollectionAction {
  const LinkCollectionOpened(this.collectionId);
  final String collectionId;
}

/// The finder's first level finished loading (delivery of [LinkFinderOpened]).
class LinkCollectionsLoaded extends CollectionAction {
  const LinkCollectionsLoaded(this.collections);
  final List<LinkOption> collections;
}

/// A collection's cards finished loading (delivery of [LinkCollectionOpened]).
class LinkCardsLoaded extends CollectionAction {
  const LinkCardsLoaded(this.collectionId, this.cards);
  final String collectionId;
  final List<LinkOption> cards;
}

/// Finder → link this card to a collection or another card (§4.4).
class LinkRequested extends CollectionAction {
  const LinkRequested({
    required this.cardId,
    required this.targetKind,
    required this.targetId,
  });
  final String cardId;
  final ConnectedEntityKind targetKind;
  final String targetId;
}

/// Enter / leave drag-to-reorder mode (§4.2).
class StartReorder extends CollectionAction {
  const StartReorder();
}

class EndReorder extends CollectionAction {
  const EndReorder();
}

/// A drag in reorder mode moved a card (ReorderableListView indices).
class CardMoved extends CollectionAction {
  const CardMoved(this.oldIndex, this.newIndex);
  final int oldIndex;
  final int newIndex;
}

/// Header long-press → rename the collection (§4.2).
class TitleSubmitted extends CollectionAction {
  const TitleSubmitted(this.title);
  final String title;
}

class DeactivateFeature extends CollectionAction {
  const DeactivateFeature();
}
