import 'package:knit/features/collection/domain/collection_models.dart';

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
  const LoadFailed(this.message);
  final String message;
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

/// Actions sheet → delete a card (§4.2). Links to it become broken, not gone.
class CardDeleteRequested extends CollectionAction {
  const CardDeleteRequested(this.cardId);
  final String cardId;
}

/// Actions sheet → finder → link this card to a collection (§4.4).
class LinkRequested extends CollectionAction {
  const LinkRequested({required this.cardId, required this.targetCollectionId});
  final String cardId;
  final String targetCollectionId;
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
