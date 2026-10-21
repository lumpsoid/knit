import 'package:fcis_core/fcis_core.dart';
import 'package:intl/intl.dart';
import 'package:knit/core/attachments/domain/picked_audio.dart';
import 'package:knit/core/attachments/domain/picked_image.dart';
import 'package:knit/core/ordering/fractional_index.dart';
import 'package:knit/core/recents/domain/recent_targets.dart';
import 'package:knit/features/collection/domain/collection_models.dart';
import 'package:knit/features/collection/domain/collection_outline.dart';
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

  /// Cards per feed page (§8.7): the first load reads the newest page, and
  /// each scroll toward the top reads one more.
  static const int feedPageSize = 50;

  @override
  (CollectionState, List<CollectionEffect>?) update(
    CollectionState state,
    CollectionAction action,
  ) {
    // An imported collection is read-only (docs/collection_share.md): every
    // write to it stops here, whatever the view offered.
    if (!state.canEdit && _writesHere(action)) return (state, null);
    switch (action) {
      case ViewAttached(
        :final collectionId,
        :final focusCardId,
        :final quickInput,
      ):
        return (
          state.copyWith(
            collectionId: collectionId,
            status: CollectionStatus.loading,
            quickInput: quickInput,
            focus: focusCardId == null ? null : _nextFocus(state, focusCardId),
          ),
          [
            LoadCollectionEffect(
              collectionId,
              focusCardId == null
                  ? const FeedWindow.latest(feedPageSize)
                  : FeedWindow.through(focusCardId, feedPageSize),
            ),
          ],
        );

      case ReloadRequested():
        if (state.collectionId.isEmpty) return (state, null);
        // Resync the window already loaded (everything from its oldest card
        // up), so a write or refresh never drops pages the user scrolled to.
        final window = state.cards.isEmpty
            ? const FeedWindow.latest(feedPageSize)
            : FeedWindow.from(FeedCursor.of(state.cards.first));
        return (state, [LoadCollectionEffect(state.collectionId, window)]);

      case CollectionLoaded(:final data):
        // Show the window's images + the cover through the shared image cache
        // (it loads only what it doesn't hold). Reorder is a screen *mode* the
        // user ends explicitly (Done), so carry it across the post-write
        // re-sync — a single move must not drop out of reorder mode.
        return (
          CollectionState(
            status: CollectionStatus.ready,
            collectionId: data.collectionId,
            cards: data.cards,
            olderBoundary: data.olderBoundary,
            connectionCount: data.connectionCount,
            // Stay in reorder mode only while it remains reorderable (2+ cards),
            // so a feed that shrinks under it can't strand the user with no Done.
            reordering:
                state.reordering &&
                data.ownership.canEdit &&
                data.cards.length > 1,
            // Keep the selection across a resync, minus any card that left
            // the feed (deleted or moved elsewhere meanwhile).
            selectedCardIds: _keepLoaded(state.selectedCardIds, data.cards),
            moveTargetsStatus: state.moveTargetsStatus,
            moveTargets: state.moveTargets,
            moveRecents: state.moveRecents,
            moveCardIds: _keepLoaded(state.moveCardIds, data.cards),
            quickInput: state.quickInput,
            ownership: data.ownership,
            ownerHandle: data.ownerHandle,
            outlineStatus: state.outlineStatus,
            outline: state.outline,
            // Kept until the feed reveals it: a resync landing first may not
            // hold the card yet; the load reaching it follows.
            focus: state.focus,
          ),
          [
            ShowFeedImagesEffect(_imageAttachments(data.cards)),
            ShowCoverEffect(data.coverAttachmentId),
          ],
        );

      case LoadFailed():
        return (state.copyWith(status: CollectionStatus.failed), null);

      case OlderCardsRequested():
        if (!state.hasOlder || state.loadingOlder || state.cards.isEmpty) {
          return (state, null);
        }
        return (
          state.copyWith(loadingOlder: true),
          [
            LoadOlderCardsEffect(
              collectionId: state.collectionId,
              before: FeedCursor.of(state.cards.first),
              limit: feedPageSize,
            ),
          ],
        );

      case OlderCardsLoaded(:final before, :final page):
        // Stale: the window's top moved (a resync landed first) — drop it; the
        // next scroll asks again from the current top.
        if (state.cards.isEmpty || FeedCursor.of(state.cards.first) != before) {
          return (state.copyWith(loadingOlder: false), null);
        }
        final cards = [...page.cards, ...state.cards];
        return (
          state.copyWith(
            cards: cards,
            olderBoundary: page.olderBoundary,
            clearOlderBoundary: page.olderBoundary == null,
            loadingOlder: false,
          ),
          [ShowFeedImagesEffect(_imageAttachments(cards))],
        );

      case OlderCardsLoadFailed():
        return (state.copyWith(loadingOlder: false), null);

      case ComposerSubmitted(
        :final text,
        :final images,
        :final file,
        :final audio,
      ):
        final body = text.trim();
        final caption = body.isEmpty ? null : body;
        final position = _appendPosition(state.cards);
        // A staged attachment goes as its card, the (optional) text its caption.
        if (images.isNotEmpty) {
          return (
            state,
            [
              AddPhotoCardEffect(
                collectionId: state.collectionId,
                position: position,
                images: images,
                caption: caption,
                closesQuickInput: state.quickInput,
              ),
            ],
          );
        }
        // A picked file is judged by its declared mime (§4.2): an image becomes
        // an image card and an audio file an audio card (the picker derives the
        // mime from the extension), so it renders/plays like one captured
        // in-app; anything else stays a generic file card.
        if (file != null) {
          final effect = switch (CardKind.forFileMime(file.mime)) {
            CardKind.image => AddPhotoCardEffect(
              collectionId: state.collectionId,
              position: position,
              images: [PickedImage(bytes: file.bytes, mime: file.mime)],
              caption: caption,
              closesQuickInput: state.quickInput,
            ),
            CardKind.audio => AddAudioCardEffect(
              collectionId: state.collectionId,
              position: position,
              audio: PickedAudio(
                bytes: file.bytes,
                mime: file.mime,
                name: file.name,
              ),
              caption: caption,
              closesQuickInput: state.quickInput,
            ),
            _ => AddFileCardEffect(
              collectionId: state.collectionId,
              position: position,
              file: file,
              caption: caption,
              closesQuickInput: state.quickInput,
            ),
          };
          return (state, [effect]);
        }
        if (audio != null) {
          return (
            state,
            [
              AddAudioCardEffect(
                collectionId: state.collectionId,
                position: position,
                audio: audio,
                caption: caption,
                closesQuickInput: state.quickInput,
              ),
            ],
          );
        }
        if (body.isEmpty) return (state, null);
        // A pasted bare link becomes a link card (the share-capture rule).
        return (
          state,
          [
            AddCardEffect(
              collectionId: state.collectionId,
              kind: CardKind.forText(body),
              position: position,
              text: body,
              closesQuickInput: state.quickInput,
            ),
          ],
        );

      case ConnectionCardRequested(:final targetCollectionId):
        // The picker never offers this collection itself (LinkSource rule).
        if (targetCollectionId == state.collectionId) return (state, null);
        return (
          state,
          [
            AddConnectionCardEffect(
              collectionId: state.collectionId,
              position: _appendPosition(state.cards),
              targetCollectionId: targetCollectionId,
            ),
          ],
        );

      case CardDeleteRequested(:final cardId):
        // Carry the card's attachment ids so the shell can reclaim them after
        // delete; a text/link card (or a card not in the feed) has none →
        // nothing to GC.
        final card = _cardById(state.cards, cardId);
        return (
          state,
          [
            DeleteCardEffect(
              cardId,
              attachmentIds: card?.attachmentIds ?? const [],
            ),
          ],
        );

      case CollectionDeleteRequested():
        return (state, [DeleteCollectionEffect(state.collectionId)]);

      case CardShareRequested(:final cardId):
        return _shareCard(state, cardId);

      case CardSettleToggled(:final cardId):
        final card = _cardById(state.cards, cardId);
        if (card == null) return (state, null);
        return (state, _settle([card]));

      case CardEmphasisToggled(:final cardId):
        final card = _cardById(state.cards, cardId);
        if (card == null) return (state, null);
        return (state, _emphasize([card]));

      case LinkCardOpened(:final cardId):
        return _openLink(state, cardId);

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
        // The two modes are exclusive: reordering drops the selection.
        return (
          state.copyWith(reordering: true, selectedCardIds: const {}),
          null,
        );

      case EndReorder():
        return (state.copyWith(reordering: false), null);

      case CardMoved(:final oldIndex, :final newIndex):
        return _moveCard(state, oldIndex, newIndex);

      case CardSelectionToggled(:final cardId):
        if (state.reordering || _cardById(state.cards, cardId) == null) {
          return (state, null);
        }
        final selected = {...state.selectedCardIds};
        if (!selected.remove(cardId)) selected.add(cardId);
        return (state.copyWith(selectedCardIds: selected), null);

      case AllCardsSelected():
        if (!state.selecting) return (state, null);
        return (
          state.copyWith(selectedCardIds: {for (final c in state.cards) c.id}),
          null,
        );

      case SelectionSettleRequested():
        if (!state.selecting) return (state, null);
        return (
          state.copyWith(selectedCardIds: const {}),
          _settle([
            for (final c in state.cards)
              if (state.selectedCardIds.contains(c.id)) c,
          ]),
        );

      case SelectionDeleteRequested():
        if (!state.selecting) return (state, null);
        final selected = [
          for (final c in state.cards)
            if (state.selectedCardIds.contains(c.id)) c,
        ];
        return (
          state.copyWith(selectedCardIds: const {}),
          [
            DeleteCardsEffect(
              [for (final c in selected) c.id],
              attachmentIds: [for (final c in selected) ...c.attachmentIds],
            ),
          ],
        );

      case SelectionEmphasisRequested():
        if (!state.selecting) return (state, null);
        return (
          state.copyWith(selectedCardIds: const {}),
          _emphasize([
            for (final c in state.cards)
              if (state.selectedCardIds.contains(c.id)) c,
          ]),
        );

      case SelectionCleared():
        return (state.copyWith(selectedCardIds: const {}), null);

      case MoveTargetsRequested():
        if (!state.selecting) return (state, null);
        return _openMovePicker(state, state.selectedCardIds);

      case CardMoveRequested(:final cardId):
        // One card's Move is the selection's, for that card alone.
        if (state.reordering || _cardById(state.cards, cardId) == null) {
          return (state, null);
        }
        return _openMovePicker(state, {cardId});

      case MoveTargetsLoaded(:final targets, :final recentIds):
        // Moving into the collection the cards are already in is no move.
        final offered = [
          for (final t in targets)
            if (t.collectionId != state.collectionId) t,
        ];
        return (
          state.copyWith(
            moveTargetsStatus: MoveTargetsStatus.ready,
            moveTargets: offered,
            moveRecents: RecentTargets(
              recentIds,
            ).among(offered, (t) => t.collectionId),
          ),
          null,
        );

      case MoveTargetsLoadFailed():
        return (
          state.copyWith(moveTargetsStatus: MoveTargetsStatus.failed),
          null,
        );

      case MoveTargetChosen(:final target):
        final idle = _pickerClosed(state);
        if (state.moveCardIds.isEmpty ||
            target.collectionId == state.collectionId) {
          return (idle, null);
        }
        return (idle, [LoadMoveTargetTailEffect(target)]);

      case MoveToNewCollectionChosen(:final title):
        final idle = _pickerClosed(state);
        final trimmed = title.trim();
        if (state.moveCardIds.isEmpty || trimmed.isEmpty) return (idle, null);
        return (idle, [CreateMoveTargetEffect(trimmed)]);

      case MoveTargetTailLoaded(:final target, :final lastPosition):
        return _moveCards(state, target, lastPosition);

      case OutlineRequested():
        if (state.collectionId.isEmpty) return (state, null);
        return (
          state.copyWith(outlineStatus: OutlineStatus.loading),
          [LoadOutlineEffect(state.collectionId)],
        );

      case OutlineCardsLoaded(:final cards):
        return (
          state.copyWith(
            outlineStatus: OutlineStatus.ready,
            outline: CollectionOutline.of(cards),
          ),
          null,
        );

      case OutlineLoadFailed():
        return (state.copyWith(outlineStatus: OutlineStatus.failed), null);

      case CardRevealRequested(:final cardId):
        final focused = state.copyWith(focus: _nextFocus(state, cardId));
        if (_cardById(state.cards, cardId) != null) return (focused, null);
        // Not loaded yet: widen the window down to the card (the search-hit
        // entry path); the feed reveals it once the load lands.
        return (
          focused,
          [
            LoadCollectionEffect(
              state.collectionId,
              FeedWindow.through(cardId, feedPageSize),
            ),
          ],
        );

      case DeactivateFeature():
        // The composer releases the recorder itself, with the page.
        return (
          state.copyWith(
            reordering: false,
            selectedCardIds: const {},
            moveCardIds: const {},
          ),
          const [ReleaseImagesEffect()],
        );
    }
  }

  /// Resolve [cardId] to its shareable content and emit a [ShareCardEffect];
  /// a missing card or an empty text card with no attachment is a pure no-op.
  /// An image card shares its photos and a file card its file (under its
  /// stored name); other kinds share text only.
  (CollectionState, List<CollectionEffect>?) _shareCard(
    CollectionState state,
    String cardId,
  ) {
    final card = _cardById(state.cards, cardId);
    if (card == null) return (state, null);
    final text = card.text?.trim();
    final hasText = text != null && text.isNotEmpty;
    final attachmentIds = switch (card.kind) {
      CardKind.image => card.imageIds,
      CardKind.file => [?card.attachmentId],
      _ => const <String>[],
    };
    if (!hasText && attachmentIds.isEmpty) return (state, null);
    return (
      state,
      [
        ShareCardEffect(
          text: hasText ? text : null,
          attachmentIds: attachmentIds,
          imageBaseName: _shareBaseName(card),
          fileName: card.kind == CardKind.file ? card.fileName : null,
        ),
      ],
    );
  }

  /// Resolve [cardId] to its stored link text and emit an [OpenLinkEffect]; a
  /// missing card or one with no text is a pure no-op (nothing to open). The URL
  /// is the card body verbatim — scheme-defaulting is the LinkLauncher's job.
  (CollectionState, List<CollectionEffect>?) _openLink(
    CollectionState state,
    String cardId,
  ) {
    final card = _cardById(state.cards, cardId);
    final url = card?.text?.trim();
    if (url == null || url.isEmpty) return (state, null);
    return (state, [OpenLinkEffect(url)]);
  }

  /// The settle write for [cards] (§3.3), as the domain decides it; null when
  /// nothing would change.
  static List<CollectionEffect>? _settle(List<FeedCard> cards) {
    final change = SettleChange.of(cards);
    if (change.cardIds.isEmpty) return null;
    return [SettleCardsEffect(change.cardIds, settled: change.settled)];
  }

  /// The emphasis write for [cards] (§3.3), as the domain decides it; null
  /// when nothing would change.
  static List<CollectionEffect>? _emphasize(List<FeedCard> cards) {
    final change = EmphasisChange.of(cards);
    if (change.cardIds.isEmpty) return null;
    return [
      EmphasizeCardsEffect(change.cardIds, emphasized: change.emphasized),
    ];
  }

  /// A fresh request to reveal [cardId], told apart from the current one.
  static FeedFocus _nextFocus(CollectionState state, String cardId) =>
      FeedFocus(cardId, (state.focus?.serial ?? 0) + 1);

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

  /// Every image of the image cards in [cards], and the cover of each
  /// collection-link tile (§4.2) — what the feed shows.
  static List<String> _imageAttachments(List<FeedCard> cards) => [
    for (final card in cards) ...[
      ...card.imageIds,
      ?card.collectionLink?.coverAttachmentId,
    ],
  ];

  /// The ids in [selected] that are still among [cards].
  static Set<String> _keepLoaded(Set<String> selected, List<FeedCard> cards) {
    if (selected.isEmpty) return selected;
    return {
      for (final c in cards)
        if (selected.contains(c.id)) c.id,
    };
  }

  /// Open the move picker for [cardIds]: load its targets.
  static (CollectionState, List<CollectionEffect>?) _openMovePicker(
    CollectionState state,
    Set<String> cardIds,
  ) => (
    state.copyWith(
      moveTargetsStatus: MoveTargetsStatus.loading,
      moveCardIds: cardIds,
    ),
    const [LoadMoveTargetsEffect()],
  );

  /// The picker closed on a choice: its rows are no longer needed. The cards
  /// to move stay until the move is made.
  static CollectionState _pickerClosed(CollectionState state) => state.copyWith(
    moveTargetsStatus: MoveTargetsStatus.idle,
    moveTargets: const [],
    moveRecents: const [],
  );

  /// Move the picker's cards into [target]: append them after the target's
  /// [lastPosition] in their feed order (so they keep their relative order),
  /// drop them from this feed optimistically, and leave selection mode.
  (CollectionState, List<CollectionEffect>?) _moveCards(
    CollectionState state,
    MoveTarget target,
    String? lastPosition,
  ) {
    final moving = [
      for (final c in state.cards)
        if (state.moveCardIds.contains(c.id)) c,
    ];
    if (moving.isEmpty) {
      return (
        state.copyWith(selectedCardIds: const {}, moveCardIds: const {}),
        null,
      );
    }
    final positions = <String, String>{};
    var previous = lastPosition;
    for (final card in moving) {
      final position = previous == null
          ? FractionalIndex.first()
          : FractionalIndex.keyAfter(previous);
      positions[card.id] = position;
      previous = position;
    }
    return (
      state.copyWith(
        cards: [
          for (final c in state.cards)
            if (!positions.containsKey(c.id)) c,
        ],
        selectedCardIds: const {},
        moveCardIds: const {},
      ),
      [MoveCardsEffect(target: target, positions: positions)],
    );
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
    if (newIndex == oldIndex) return (state, null);

    final cards = [...state.cards];
    final moved = cards.removeAt(oldIndex);
    cards.insert(newIndex, moved);

    // At the window's top, the lower neighbour is the newest *unloaded* card —
    // never null while older cards exist, or the move would jump past them.
    final before = newIndex > 0
        ? cards[newIndex - 1].position
        : state.olderBoundary?.position;
    final after = newIndex < cards.length - 1
        ? cards[newIndex + 1].position
        : null;
    final position = FractionalIndex.between(before, after);

    cards[newIndex] = moved.copyWith(position: position);
    return (
      state.copyWith(cards: cards),
      [ReorderCardEffect(moved.id, position)],
    );
  }

  /// Whether [action] writes to this collection — its cards, their placement,
  /// its header or its existence. A link *from* another card into it does not.
  static bool _writesHere(CollectionAction action) => switch (action) {
    ComposerSubmitted() ||
    ConnectionCardRequested() ||
    CardDeleteRequested() ||
    CollectionDeleteRequested() ||
    CardSettleToggled() ||
    CardEmphasisToggled() ||
    StartReorder() ||
    CardMoved() ||
    CardSelectionToggled() ||
    AllCardsSelected() ||
    SelectionSettleRequested() ||
    SelectionDeleteRequested() ||
    SelectionEmphasisRequested() ||
    MoveTargetsRequested() ||
    CardMoveRequested() ||
    MoveTargetChosen() ||
    MoveToNewCollectionChosen() => true,
    _ => false,
  };
}
