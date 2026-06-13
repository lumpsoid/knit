import 'package:fcis_core/fcis_core.dart';
import 'package:knit/core/ordering/fractional_index.dart';
import 'package:knit/features/collection/domain/collection_models.dart';
import 'package:knit/features/collection/presentation/collection_action.dart';
import 'package:knit/features/collection/presentation/collection_effect.dart';
import 'package:knit/features/collection/presentation/collection_state.dart';

/// Pure reducer for the Collection screen (fcis.md §6.1). Owns **all** card
/// placement math: append keys and reorder midpoints are minted here with
/// [FractionalIndex] (§8.7) from the loaded feed, so the write repo just
/// persists the position it is handed. Reorder is applied optimistically to the
/// local list and re-synced from the projection after the write.
class CollectionUpdater
    implements Updater<CollectionState, CollectionAction, CollectionEffect> {
  const CollectionUpdater();

  @override
  (CollectionState, List<CollectionEffect>?) update(
    CollectionState state,
    CollectionAction action,
  ) {
    switch (action) {
      case ViewAttached(:final collectionId):
        return (
          state.copyWith(
            collectionId: collectionId,
            status: CollectionStatus.loading,
          ),
          [LoadCollectionEffect(collectionId)],
        );

      case ReloadRequested():
        if (state.collectionId.isEmpty) return (state, null);
        return (state, [LoadCollectionEffect(state.collectionId)]);

      case CollectionLoaded(:final data):
        // Preserve the decoded-bytes cache across reloads (ids are immutable),
        // and load any image card whose bytes we don't already hold.
        final toLoad = _uncachedImageAttachments(data.cards, state.imageBytes);
        return (
          CollectionState(
            status: CollectionStatus.ready,
            collectionId: data.collectionId,
            title: data.title,
            coverAttachmentId: data.coverAttachmentId,
            cards: data.cards,
            imageBytes: state.imageBytes,
            linkTargets: data.linkTargets,
          ),
          toLoad.isEmpty
              ? null
              : [for (final id in toLoad) LoadImageBytesEffect(id)],
        );

      case ImageBytesLoaded(:final attachmentId, :final bytes):
        // Cache only on success; a miss leaves the placeholder in place.
        if (bytes == null) return (state, null);
        return (
          state.copyWith(
            imageBytes: {...state.imageBytes, attachmentId: bytes},
          ),
          null,
        );

      case LoadFailed(:final message):
        return (
          state.copyWith(
            status: CollectionStatus.failed,
            errorMessage: message,
          ),
          null,
        );

      case ComposerSubmitted(:final text):
        final body = text.trim();
        if (body.isEmpty) return (state, null);
        return (
          state,
          [
            AddCardEffect(
              collectionId: state.collectionId,
              kind: CardKind.text,
              position: _appendPosition(state.cards),
              text: body,
            ),
          ],
        );

      case LinkCardSubmitted(:final url):
        final body = url.trim();
        if (body.isEmpty) return (state, null);
        return (
          state,
          [
            AddCardEffect(
              collectionId: state.collectionId,
              kind: CardKind.link,
              position: _appendPosition(state.cards),
              text: body,
            ),
          ],
        );

      case CardDeleteRequested(:final cardId):
        return (state, [DeleteCardEffect(cardId)]);

      case LinkRequested(:final cardId, :final targetCollectionId):
        return (
          state,
          [LinkEffect(cardId: cardId, targetCollectionId: targetCollectionId)],
        );

      case StartReorder():
        return (state.copyWith(reordering: true), null);

      case EndReorder():
        return (state.copyWith(reordering: false), null);

      case CardMoved(:final oldIndex, :final newIndex):
        return _moveCard(state, oldIndex, newIndex);

      case TitleSubmitted(:final title):
        final trimmed = title.trim();
        if (trimmed.isEmpty) return (state, null);
        // Optimistic header update; the reload after the write confirms it.
        return (
          state.copyWith(title: trimmed),
          [EditTitleEffect(state.collectionId, trimmed)],
        );

      case DeactivateFeature():
        return (state, null);
    }
  }

  /// Distinct `attachment_id`s of image cards whose bytes aren't cached yet.
  static List<String> _uncachedImageAttachments(
    List<FeedCard> cards,
    Map<String, Object?> cache,
  ) {
    final ids = <String>{};
    for (final card in cards) {
      final id = card.attachmentId;
      if (card.kind == CardKind.image && id != null && !cache.containsKey(id)) {
        ids.add(id);
      }
    }
    return ids.toList(growable: false);
  }

  /// Append key: after the last card, or the first key for an empty feed.
  static String _appendPosition(List<FeedCard> cards) =>
      cards.isEmpty ? FractionalIndex.first() : FractionalIndex.keyAfter(cards.last.position);

  /// Reorder: apply the move locally, mint a key between the new neighbours,
  /// and emit the placement write. ReorderableListView's `newIndex` is the
  /// pre-removal slot, so it shifts down by one when moving downward.
  (CollectionState, List<CollectionEffect>?) _moveCard(
    CollectionState state,
    int oldIndex,
    int newIndex,
  ) {
    final target = newIndex > oldIndex ? newIndex - 1 : newIndex;
    if (target == oldIndex) return (state, null);

    final cards = [...state.cards];
    final moved = cards.removeAt(oldIndex);
    cards.insert(target, moved);

    final before = target > 0 ? cards[target - 1].position : null;
    final after = target < cards.length - 1 ? cards[target + 1].position : null;
    final position = FractionalIndex.between(before, after);

    cards[target] = moved.copyWith(position: position);
    return (
      state.copyWith(cards: cards),
      [ReorderCardEffect(moved.id, position)],
    );
  }
}
