import 'package:knit/core/attachments/domain/picked_audio.dart';
import 'package:knit/core/attachments/domain/picked_file.dart';
import 'package:knit/core/attachments/domain/picked_image.dart';
import 'package:knit/features/collection/domain/collection_models.dart';
import 'package:knit/features/connections/domain/connections_models.dart';

/// Intents + async-result deliveries for the Collection screen (fcis.md §6.4).
/// All payloads are scalars / feature-local view-models (no sync-core types).
sealed class CollectionAction {
  const CollectionAction();
}

/// View attached for [collectionId] (read from the route-args carrier, §2).
/// [focusCardId] is a card the entry must reveal (e.g. a search hit), so the
/// first load reaches back far enough to include it.
class ViewAttached extends CollectionAction {
  const ViewAttached(
    this.collectionId, {
    this.focusCardId,
    this.quickInput = false,
  });
  final String collectionId;
  final String? focusCardId;

  /// Opened for one quick card from a home-screen widget.
  final bool quickInput;
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

/// The feed scrolled near its loaded top — page in older cards (§8.7). A
/// no-op while a page is in flight or nothing older exists.
class OlderCardsRequested extends CollectionAction {
  const OlderCardsRequested();
}

/// Delivery of [OlderCardsRequested]: [page] holds the cards older than
/// [before] (the window's oldest card when requested). Dropped as stale if the
/// window moved meanwhile (e.g. a resync landed first).
class OlderCardsLoaded extends CollectionAction {
  const OlderCardsLoaded(this.before, this.page);
  final FeedCursor before;
  final FeedPage page;
}

/// Delivery of [OlderCardsRequested] on failure: the next scroll retries.
class OlderCardsLoadFailed extends CollectionAction {
  const OlderCardsLoadFailed();
}

/// The bottom composer sent (§4.2): [text] as a text card, or as the caption
/// of the staged attachment riding along — [images] (one image card holding
/// them all, in order), a [file], or an [audio] clip (one kind at most; the
/// composer picks it).
class ComposerSubmitted extends CollectionAction {
  const ComposerSubmitted(
    this.text, {
    this.images = const [],
    this.file,
    this.audio,
  });
  final String text;
  final List<PickedImage> images;
  final PickedFile? file;
  final PickedAudio? audio;
}

/// The "+" sheet's Connection block picked the [targetKind] entity
/// [targetId] — a collection or a card (§4.2): append a Connection card
/// pointing at it. [composerText] is what the composer input held: it may
/// become the card's label (`ConnectionCardText`).
class ConnectionCardRequested extends CollectionAction {
  const ConnectionCardRequested(
    this.targetKind,
    this.targetId, {
    this.composerText = '',
  });
  final ConnectedEntityKind targetKind;
  final String targetId;
  final String composerText;
}

/// The Connection block's "New collection" line sent [title] (§4.4): create
/// that collection and append a Connection card pointing at it, in one go.
/// [composerText] as in [ConnectionCardRequested].
class ConnectionToNewCollectionRequested extends CollectionAction {
  const ConnectionToNewCollectionRequested(
    this.title, {
    this.composerText = '',
  });
  final String title;
  final String composerText;
}

/// Actions sheet → delete a card (§4.2). Links to it become broken, not gone.
class CardDeleteRequested extends CollectionAction {
  const CardDeleteRequested(this.cardId);
  final String cardId;
}

/// The ⋮ menu's Delete (confirmed by the user): delete this collection.
class CollectionDeleteRequested extends CollectionAction {
  const CollectionDeleteRequested();
}

/// Actions sheet → share a card through the system share sheet (§4.2). Text
/// cards share their text; an image card shares the photo plus its caption.
class CardShareRequested extends CollectionAction {
  const CardShareRequested(this.cardId);
  final String cardId;
}

/// Actions sheet → settle [cardId], or unsettle it when it is settled (§3.3).
class CardSettleToggled extends CollectionAction {
  const CardSettleToggled(this.cardId);
  final String cardId;
}

/// Actions sheet → emphasize [cardId], or unemphasize it when it is
/// emphasized (§3.3).
class CardEmphasisToggled extends CollectionAction {
  const CardEmphasisToggled(this.cardId);
  final String cardId;
}

/// Tapped a link card's URL → open it in the system browser (§4.2). The updater
/// resolves the card to its stored link text and emits the open effect; the
/// launch itself lives behind the LinkLauncher port.
class LinkCardOpened extends CollectionAction {
  const LinkCardOpened(this.cardId);
  final String cardId;
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

/// Finder → "New collection" sent [title]: create it and link [cardId] to
/// it, in one go (§4.4).
class LinkToNewCollectionRequested extends CollectionAction {
  const LinkToNewCollectionRequested({
    required this.cardId,
    required this.title,
  });
  final String cardId;
  final String title;
}

/// Finder → a ✓ target tapped again: remove the link [linkId] (§4.4).
class UnlinkRequested extends CollectionAction {
  const UnlinkRequested(this.linkId);
  final String linkId;
}

/// Enter / leave drag-to-reorder mode (§4.2).
class StartReorder extends CollectionAction {
  const StartReorder();
}

class EndReorder extends CollectionAction {
  const EndReorder();
}

/// A drag in reorder mode moved a card. Indices follow `onReorderItem`:
/// [newIndex] is the card's final slot, already adjusted for the removal.
class CardMoved extends CollectionAction {
  const CardMoved(this.oldIndex, this.newIndex);
  final int oldIndex;
  final int newIndex;
}

/// Long-press a card (enters multi-select) or tap one while selecting: flip
/// whether [cardId] is selected. Deselecting the last card leaves the mode.
class CardSelectionToggled extends CollectionAction {
  const CardSelectionToggled(this.cardId);
  final String cardId;
}

/// Select every loaded card.
class AllCardsSelected extends CollectionAction {
  const AllCardsSelected();
}

/// The selection's Settle / Unsettle (§3.3): settle the selected cards, or
/// unsettle them all once every one is settled. Leaves selection mode.
class SelectionSettleRequested extends CollectionAction {
  const SelectionSettleRequested();
}

/// The selection's Delete (confirmed by the user): delete the selected cards.
/// Links to them become broken, not gone. Leaves selection mode.
class SelectionDeleteRequested extends CollectionAction {
  const SelectionDeleteRequested();
}

/// The selection's Emphasize / Unemphasize (§3.3), by the settle rule.
/// Leaves selection mode.
class SelectionEmphasisRequested extends CollectionAction {
  const SelectionEmphasisRequested();
}

/// The selection's "Link to…" (§4.2) picked the [targetKind] entity
/// [targetId], titled [targetTitle]: link every selected card that may link
/// there (`LinkSelection`). Leaves selection mode.
class SelectionLinkRequested extends CollectionAction {
  const SelectionLinkRequested({
    required this.targetKind,
    required this.targetId,
    required this.targetTitle,
  });
  final ConnectedEntityKind targetKind;
  final String targetId;
  final String targetTitle;
}

/// The selection's "Link to…" → "New collection" sent [title]: create it and
/// link every selected card to it, in one go. Leaves selection mode.
class SelectionLinkToNewCollectionRequested extends CollectionAction {
  const SelectionLinkToNewCollectionRequested(this.title);
  final String title;
}

/// Leave multi-select mode (the app-bar "✕" or system back).
class SelectionCleared extends CollectionAction {
  const SelectionCleared();
}

/// The selection's "Move" opened the target picker: load its collections.
/// The selected cards are the ones that move.
class MoveTargetsRequested extends CollectionAction {
  const MoveTargetsRequested();
}

/// The card actions sheet's "Move to collection…" (§4.2): the same picker and
/// move as the selection's, for [cardId] alone.
class CardMoveRequested extends CollectionAction {
  const CardMoveRequested(this.cardId);
  final String cardId;
}

/// Delivery of the picker's read: every live collection, and the ids of
/// those recently moved into, most recent first (device-local, §4.2).
class MoveTargetsLoaded extends CollectionAction {
  const MoveTargetsLoaded(this.targets, {this.recentIds = const []});
  final List<MoveTarget> targets;
  final List<String> recentIds;
}

/// Delivery of the picker's read on failure.
class MoveTargetsLoadFailed extends CollectionAction {
  const MoveTargetsLoadFailed();
}

/// The picker chose [target]: move the cards it was opened for there.
class MoveTargetChosen extends CollectionAction {
  const MoveTargetChosen(this.target);
  final MoveTarget target;
}

/// The picker's "New collection" line sent [title]: create that collection,
/// then move the cards the picker was opened for into it.
class MoveToNewCollectionChosen extends CollectionAction {
  const MoveToNewCollectionChosen(this.title);
  final String title;
}

/// Delivery of [MoveTargetChosen]'s read: [lastPosition] is the target's
/// newest card position (null when it is empty), so the moved cards append.
class MoveTargetTailLoaded extends CollectionAction {
  const MoveTargetTailLoaded(this.target, this.lastPosition);
  final MoveTarget target;
  final String? lastPosition;
}

/// The ⋮ menu's Outline opened (§4.2): load the collection's headings.
class OutlineRequested extends CollectionAction {
  const OutlineRequested();
}

/// Delivery of [OutlineRequested]: the collection's whole feed, in order.
class OutlineCardsLoaded extends CollectionAction {
  const OutlineCardsLoaded(this.cards);
  final List<FeedCard> cards;
}

/// Delivery of [OutlineRequested] on failure.
class OutlineLoadFailed extends CollectionAction {
  const OutlineLoadFailed();
}

/// An Outline row or an in-collection search hit (§4.2) was chosen: reveal and
/// highlight [cardId] in the feed, first loading the feed down to it when it
/// isn't loaded yet.
class CardRevealRequested extends CollectionAction {
  const CardRevealRequested(this.cardId);
  final String cardId;
}

class DeactivateFeature extends CollectionAction {
  const DeactivateFeature();
}
