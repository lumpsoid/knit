import 'package:knit/features/connections/domain/connections_models.dart';

/// Async-work descriptors for the Card Edit page (fcis.md §6.4).
sealed class CardEditEffect {
  const CardEditEffect();
}

/// Persist the card's edited text (§4.3). [text] is the trimmed body.
class SaveCardEffect extends CardEditEffect {
  const SaveCardEffect(this.cardId, this.text);
  final String cardId;
  final String text;
}

/// Settle (or, with [settled] false, unsettle) [cardId] (§3.3).
class SetSettledEffect extends CardEditEffect {
  const SetSettledEffect(this.cardId, {required this.settled});
  final String cardId;
  final bool settled;
}

/// Emphasize (or, with [emphasized] false, unemphasize) [cardId] (§3.3).
class SetEmphasizedEffect extends CardEditEffect {
  const SetEmphasizedEffect(this.cardId, {required this.emphasized});
  final String cardId;
  final bool emphasized;
}

/// Find out whether [cardId] is [collectionId]'s home-timeline preview card.
class LoadTimelinePreviewEffect extends CardEditEffect {
  const LoadTimelinePreviewEffect({
    required this.cardId,
    required this.collectionId,
  });
  final String cardId;
  final String collectionId;
}

/// Ask the Timeline to re-read: the edit changed its last-card preview.
class RefreshTimelineEffect extends CardEditEffect {
  const RefreshTimelineEffect();
}

// --- links (subtask 3) -----------------------------------------------------

/// Load the card's outgoing links.
class LoadLinksEffect extends CardEditEffect {
  const LoadLinksEffect(this.cardId);
  final String cardId;
}

/// Create a link from [cardId] to the chosen target.
class AddLinkEffect extends CardEditEffect {
  const AddLinkEffect({
    required this.cardId,
    required this.targetKind,
    required this.targetId,
  });
  final String cardId;
  final ConnectedEntityKind targetKind;
  final String targetId;
}

/// Delete a link record.
class RemoveLinkEffect extends CardEditEffect {
  const RemoveLinkEffect(this.linkId);
  final String linkId;
}

// --- attachment (subtask 4) ------------------------------------------------

/// The section shows the *images* [attachmentIds] (empty = no image): hand
/// them to the shared image cache, which loads those it doesn't hold yet.
/// Audio/file attachments render from their metadata, so they show no image.
class ShowImageEffect extends CardEditEffect {
  const ShowImageEffect(this.attachmentIds);
  final List<String> attachmentIds;
}

/// The page left: let the shared image cache drop its image.
class ReleaseImageEffect extends CardEditEffect {
  const ReleaseImageEffect();
}

/// Pick photos from the gallery, store them, and make [cardId] an image card
/// holding [keptImageIds] followed by them (§4.2). [replacedAttachmentId] is
/// a non-image attachment the photos take the place of, GC'd once they do.
class PickImageEffect extends CardEditEffect {
  const PickImageEffect({
    required this.cardId,
    this.keptImageIds = const [],
    this.replacedAttachmentId,
  });
  final String cardId;
  final List<String> keptImageIds;
  final String? replacedAttachmentId;
}

/// Drop [removedId] from [cardId]'s images, leaving [remainingIds] (empty
/// makes it a text card), and GC it.
class RemoveImageEffect extends CardEditEffect {
  const RemoveImageEffect({
    required this.cardId,
    required this.remainingIds,
    required this.removedId,
  });
  final String cardId;
  final List<String> remainingIds;
  final String removedId;
}

/// Pick any file, store it (routed to image/audio/file by its mime, §4.2), point
/// [cardId] at the new attachment in place of all it had, and GC the
/// [previousAttachmentIds].
class PickFileEffect extends CardEditEffect {
  const PickFileEffect({
    required this.cardId,
    this.previousAttachmentIds = const [],
  });
  final String cardId;
  final List<String> previousAttachmentIds;
}

/// Shrink each of [cardId]'s images [attachmentIds], store the smaller copies,
/// point the card at them (in the same order), and GC the originals they
/// replace. An image with nothing to gain stays as it is.
class OptimizeImageEffect extends CardEditEffect {
  const OptimizeImageEffect({
    required this.cardId,
    required this.attachmentIds,
  });
  final String cardId;
  final List<String> attachmentIds;
}

/// Clear [cardId]'s attachment and GC the [previousAttachmentIds].
class RemoveAttachmentEffect extends CardEditEffect {
  const RemoveAttachmentEffect({
    required this.cardId,
    this.previousAttachmentIds = const [],
  });
  final String cardId;
  final List<String> previousAttachmentIds;
}
