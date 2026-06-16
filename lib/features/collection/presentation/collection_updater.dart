import 'package:fcis_core/fcis_core.dart';
import 'package:intl/intl.dart';
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
            // A fresh entry into a collection starts with no pending preview.
            clearPendingImage: true,
          ),
          [LoadCollectionEffect(collectionId)],
        );

      case ReloadRequested():
        if (state.collectionId.isEmpty) return (state, null);
        return (state, [LoadCollectionEffect(state.collectionId)]);

      case CollectionLoaded(:final data):
        // Preserve the decoded-bytes cache across reloads (ids are immutable),
        // and load any image card whose bytes we don't already hold. Reorder is
        // a screen *mode* the user ends explicitly (Done), so carry it across the
        // post-write re-sync — a single move must not drop out of reorder mode.
        final toLoad = _uncachedImageAttachments(data.cards, state.imageBytes);
        return (
          CollectionState(
            status: CollectionStatus.ready,
            collectionId: data.collectionId,
            title: data.title,
            coverAttachmentId: data.coverAttachmentId,
            cards: data.cards,
            imageBytes: state.imageBytes,
            // Link-finder caches are deliberately dropped on reload: a write may
            // have changed the targets, so the finder re-reads fresh on reopen.
            // Stay in reorder mode only while it remains reorderable (2+ cards),
            // so a feed that shrinks under it can't strand the user with no Done.
            reordering: state.reordering && data.cards.length > 1,
            // A resync (pull-to-refresh / post-write) must not drop an image the
            // user is still composing a caption for.
            pendingImage: state.pendingImage,
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

      case LoadFailed():
        return (state.copyWith(status: CollectionStatus.failed), null);

      case ComposerSubmitted(:final text):
        final body = text.trim();
        final pending = state.pendingImage;
        // A pending image wins: send it as an image card with the (optional)
        // text as its caption, and clear the preview optimistically.
        if (pending != null) {
          return (
            state.copyWith(clearPendingImage: true),
            [
              AddPhotoCardEffect(
                collectionId: state.collectionId,
                position: _appendPosition(state.cards),
                image: pending,
                caption: body.isEmpty ? null : body,
              ),
            ],
          );
        }
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

      case PickImageRequested():
        return (state, const [PickImageEffect()]);

      case ImagePicked(:final image):
        // Cancelled pick ⇒ no change; otherwise stage it as the preview.
        if (image == null) return (state, null);
        return (state.copyWith(pendingImage: image), null);

      case PendingImageCleared():
        return (state.copyWith(clearPendingImage: true), null);

      case CardDeleteRequested(:final cardId):
        return (state, [DeleteCardEffect(cardId)]);

      case CardShareRequested(:final cardId):
        return _shareCard(state, cardId);

      case LinkFinderOpened():
        return (state, const [LoadLinkCollectionsEffect()]);

      case LinkCollectionOpened(:final collectionId):
        // Drill is a cache hit ⇒ pure no-op; a miss loads that collection's
        // cards once (the sheet shows a spinner until they arrive).
        if (state.linkCardsByCollection.containsKey(collectionId)) {
          return (state, null);
        }
        return (state, [LoadCollectionCardsEffect(collectionId)]);

      case LinkCollectionsLoaded(:final collections):
        return (state.copyWith(linkCollections: collections), null);

      case LinkCardsLoaded(:final collectionId, :final cards):
        return (
          state.copyWith(
            linkCardsByCollection: {
              ...state.linkCardsByCollection,
              collectionId: cards,
            },
          ),
          null,
        );

      case LinkRequested(:final cardId, :final targetKind, :final targetId):
        return (
          state,
          [
            LinkEffect(
              cardId: cardId,
              targetKind: targetKind,
              targetId: targetId,
            ),
          ],
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
        return (
          state.copyWith(reordering: false, clearPendingImage: true),
          null,
        );
    }
  }

  /// Resolve [cardId] to its shareable content and emit a [ShareCardEffect];
  /// a missing card or an empty text card with no image is a pure no-op. Only an
  /// image card carries an attachment to share; other kinds share text only.
  (CollectionState, List<CollectionEffect>?) _shareCard(
    CollectionState state,
    String cardId,
  ) {
    final card = _cardById(state.cards, cardId);
    if (card == null) return (state, null);
    final text = card.text?.trim();
    final hasText = text != null && text.isNotEmpty;
    final attachmentId = card.kind == CardKind.image ? card.attachmentId : null;
    if (!hasText && attachmentId == null) return (state, null);
    return (
      state,
      [
        ShareCardEffect(
          text: hasText ? text : null,
          attachmentId: attachmentId,
          imageBaseName: _shareBaseName(card),
        ),
      ],
    );
  }

  static FeedCard? _cardById(List<FeedCard> cards, String id) {
    for (final card in cards) {
      if (card.id == id) return card;
    }
    return null;
  }

  /// The date-stamped file-name stem for a shared photo: the card's capture date
  /// (§6.1) plus `knit` (e.g. `2026-06-16-knit`); just `knit` if the date can't
  /// be decoded. Pure — the date comes from the immutable card id, never a clock.
  static String _shareBaseName(FeedCard card) {
    final at = card.capturedAt;
    if (at == null) return 'knit';
    return '${DateFormat('yyyy-MM-dd').format(at)}-knit';
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
  static String _appendPosition(List<FeedCard> cards) => cards.isEmpty
      ? FractionalIndex.first()
      : FractionalIndex.keyAfter(cards.last.position);

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
