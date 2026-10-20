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
  const ViewAttached(this.collectionId, {this.focusCardId});
  final String collectionId;
  final String? focusCardId;
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
/// of the one staged attachment riding along — an [image], a [file], or an
/// [audio] clip (at most one is set; the composer picks it).
class ComposerSubmitted extends CollectionAction {
  const ComposerSubmitted(this.text, {this.image, this.file, this.audio});
  final String text;
  final PickedImage? image;
  final PickedFile? file;
  final PickedAudio? audio;
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

/// Leave multi-select mode (the app-bar "✕" or system back).
class SelectionCleared extends CollectionAction {
  const SelectionCleared();
}

/// The selection's "Move" opened the target picker: load its collections.
class MoveTargetsRequested extends CollectionAction {
  const MoveTargetsRequested();
}

/// Delivery of [MoveTargetsRequested]: every live collection.
class MoveTargetsLoaded extends CollectionAction {
  const MoveTargetsLoaded(this.targets);
  final List<MoveTarget> targets;
}

/// Delivery of [MoveTargetsRequested] on failure.
class MoveTargetsLoadFailed extends CollectionAction {
  const MoveTargetsLoadFailed();
}

/// The picker chose [target]: move the selected cards there.
class MoveTargetChosen extends CollectionAction {
  const MoveTargetChosen(this.target);
  final MoveTarget target;
}

/// Delivery of [MoveTargetChosen]'s read: [lastPosition] is the target's
/// newest card position (null when it is empty), so the moved cards append.
class MoveTargetTailLoaded extends CollectionAction {
  const MoveTargetTailLoaded(this.target, this.lastPosition);
  final MoveTarget target;
  final String? lastPosition;
}

class DeactivateFeature extends CollectionAction {
  const DeactivateFeature();
}
