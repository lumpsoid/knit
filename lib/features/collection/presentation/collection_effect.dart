import 'package:knit/core/attachments/domain/picked_audio.dart';
import 'package:knit/core/attachments/domain/picked_file.dart';
import 'package:knit/core/attachments/domain/picked_image.dart';
import 'package:knit/features/collection/domain/collection_models.dart';
import 'package:knit/features/connections/domain/connections_models.dart';

/// Async-work descriptors for the Collection screen (fcis.md §6.4). Positions
/// are pre-computed by the (pure) updater and ride in the effect, so the shell
/// and write repo carry no ordering logic.
sealed class CollectionEffect {
  const CollectionEffect();
}

/// Read the header + the [window] of the ordered feed (§8.7) for
/// [collectionId].
class LoadCollectionEffect extends CollectionEffect {
  const LoadCollectionEffect(this.collectionId, this.window);
  final String collectionId;
  final FeedWindow window;
}

/// Read every card of [collectionId] for its Outline (§4.2), delivered as
/// [OutlineCardsLoaded].
class LoadOutlineEffect extends CollectionEffect {
  const LoadOutlineEffect(this.collectionId);
  final String collectionId;
}

/// Read up to [limit] cards of [collectionId] older than [before] (§8.7).
class LoadOlderCardsEffect extends CollectionEffect {
  const LoadOlderCardsEffect({
    required this.collectionId,
    required this.before,
    required this.limit,
  });
  final String collectionId;
  final FeedCursor before;
  final int limit;
}

/// The loaded window shows the image cards' [attachmentIds] (§7.4.3): hand
/// them to the shared image cache, which loads any it doesn't hold yet.
class ShowFeedImagesEffect extends CollectionEffect {
  const ShowFeedImagesEffect(this.attachmentIds);
  final List<String> attachmentIds;
}

/// The title card shows the cover [attachmentId] (§7.4.1; null = no cover).
class ShowCoverEffect extends CollectionEffect {
  const ShowCoverEffect(this.attachmentId);
  final String? attachmentId;
}

/// The page left: let the shared image cache drop this page's images.
class ReleaseImagesEffect extends CollectionEffect {
  const ReleaseImagesEffect();
}

/// Append a card of [kind] at [position] (§8.4). [text] is the body or URL.
class AddCardEffect extends CollectionEffect {
  const AddCardEffect({
    required this.collectionId,
    required this.kind,
    required this.position,
    this.text,
    this.closesQuickInput = false,
  });
  final String collectionId;
  final CardKind kind;
  final String position;
  final String? text;

  /// Leave the quick-input page once the card is saved.
  final bool closesQuickInput;
}

/// Store the already-picked [images] (§7.4.8), then append one image card at
/// [position] holding them all in order (§4.2) and carrying [caption] (the
/// composer text, already trimmed; null when blank). The attachment ids are
/// minted in the shell from [images] — unlike a text/link [AddCardEffect],
/// which carries no attachment.
class AddPhotoCardEffect extends CollectionEffect {
  const AddPhotoCardEffect({
    required this.collectionId,
    required this.position,
    required this.images,
    this.caption,
    this.closesQuickInput = false,
  });
  final String collectionId;
  final String position;
  final List<PickedImage> images;
  final String? caption;

  /// Leave the quick-input page once the card is saved.
  final bool closesQuickInput;
}

/// Store the recorded [audio] (§7.4.8), then append an audio card at [position]
/// carrying [caption] (the composer text, already trimmed; null when blank). The
/// audio twin of [AddPhotoCardEffect].
class AddAudioCardEffect extends CollectionEffect {
  const AddAudioCardEffect({
    required this.collectionId,
    required this.position,
    required this.audio,
    this.caption,
    this.closesQuickInput = false,
  });
  final String collectionId;
  final String position;
  final PickedAudio audio;
  final String? caption;

  /// Leave the quick-input page once the card is saved.
  final bool closesQuickInput;
}

/// Store the already-picked [file] (§7.4.8), then append a file card at
/// [position] carrying [caption] (the composer text, already trimmed; null when
/// blank). The file twin of [AddPhotoCardEffect]/[AddAudioCardEffect].
class AddFileCardEffect extends CollectionEffect {
  const AddFileCardEffect({
    required this.collectionId,
    required this.position,
    required this.file,
    this.caption,
    this.closesQuickInput = false,
  });
  final String collectionId;
  final String position;
  final PickedFile file;
  final String? caption;

  /// Leave the quick-input page once the card is saved.
  final bool closesQuickInput;
}

/// Delete [cardId] (§4.2). Links to it become broken, not gone.
/// [attachmentIds] are the card's attachments (its images, audio or file) so
/// the shell can reclaim them once the card is gone; empty for text/link cards
/// (nothing to GC).
class DeleteCardEffect extends CollectionEffect {
  const DeleteCardEffect(this.cardId, {this.attachmentIds = const []});
  final String cardId;
  final List<String> attachmentIds;
}

/// Delete the collection [collectionId] (§6.1); the page then closes.
class DeleteCollectionEffect extends CollectionEffect {
  const DeleteCollectionEffect(this.collectionId);
  final String collectionId;
}

/// Delete the selected [cardIds] in one transaction (§4.2). [attachmentIds]
/// are their attachments, reclaimed once the cards are gone.
class DeleteCardsEffect extends CollectionEffect {
  const DeleteCardsEffect(this.cardIds, {this.attachmentIds = const []});
  final List<String> cardIds;
  final List<String> attachmentIds;
}

/// Share a card (§4.2). The updater resolves the card to its shareable content:
/// [text] is the body/caption (null when blank); [attachmentIds] are an image
/// card's photos or a file card's file (the shell loads their bytes). For a
/// file card [fileName] is its stored name, used verbatim; for an image card
/// [fileName] is null and the shell builds a date-stamped name from
/// [imageBaseName] + the image mime.
class ShareCardEffect extends CollectionEffect {
  const ShareCardEffect({
    this.text,
    this.attachmentIds = const [],
    required this.imageBaseName,
    this.fileName,
  });
  final String? text;
  final List<String> attachmentIds;
  final String imageBaseName;
  final String? fileName;
}

/// Open a link card's [url] in the system browser (§4.2). The updater resolves
/// the tapped card to its stored link text; the shell delegates the launch to
/// the LinkLauncher port. A read-only side-effect — it triggers no resync.
class OpenLinkEffect extends CollectionEffect {
  const OpenLinkEffect(this.url);
  final String url;
}

/// Settle (or, with [settled] false, unsettle) [cardIds] in one transaction
/// (§3.3).
class SettleCardsEffect extends CollectionEffect {
  const SettleCardsEffect(this.cardIds, {required this.settled});
  final List<String> cardIds;
  final bool settled;
}

/// Emphasize (or, with [emphasized] false, unemphasize) [cardIds] in one
/// transaction (§3.3).
class EmphasizeCardsEffect extends CollectionEffect {
  const EmphasizeCardsEffect(this.cardIds, {required this.emphasized});
  final List<String> cardIds;
  final bool emphasized;
}

class ReorderCardEffect extends CollectionEffect {
  const ReorderCardEffect(this.cardId, this.position);
  final String cardId;
  final String position;
}

/// Link [cardId] to a collection or another card (§4.4), through the shared
/// card links.
class LinkEffect extends CollectionEffect {
  const LinkEffect({
    required this.cardId,
    required this.targetKind,
    required this.targetId,
  });
  final String cardId;
  final ConnectedEntityKind targetKind;
  final String targetId;
}

/// Load every live collection for the move picker, and the ones recently
/// moved into.
class LoadMoveTargetsEffect extends CollectionEffect {
  const LoadMoveTargetsEffect();
}

/// Read [target]'s last card position, so the moved cards can append after it
/// (delivered as [MoveTargetTailLoaded]).
class LoadMoveTargetTailEffect extends CollectionEffect {
  const LoadMoveTargetTailEffect(this.target);
  final MoveTarget target;
}

/// Create the collection titled [title] as a move target. It is new and
/// empty, so it is delivered as a [MoveTargetTailLoaded] with no tail.
class CreateMoveTargetEffect extends CollectionEffect {
  const CreateMoveTargetEffect(this.title);
  final String title;
}

/// Move cards into [target] in one transaction: [positions] maps each card id
/// to its new position there, already in feed order (§8.7).
class MoveCardsEffect extends CollectionEffect {
  const MoveCardsEffect({required this.target, required this.positions});
  final MoveTarget target;
  final Map<String, String> positions;
}
