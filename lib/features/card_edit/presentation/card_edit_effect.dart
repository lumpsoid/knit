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

/// The section shows the *image* [attachmentId] (null = no image): hand it to
/// the shared image cache, which loads it if it isn't held yet. Audio/file
/// attachments render from their metadata, so they show no image.
class ShowImageEffect extends CardEditEffect {
  const ShowImageEffect(this.attachmentId);
  final String? attachmentId;
}

/// The page left: let the shared image cache drop its image.
class ReleaseImageEffect extends CardEditEffect {
  const ReleaseImageEffect();
}

/// Pick a photo (gallery/camera), store it, point [cardId] at the new image
/// attachment, and GC the [previousAttachmentId] it replaced (if any).
class PickImageEffect extends CardEditEffect {
  const PickImageEffect({
    required this.cardId,
    required this.previousAttachmentId,
  });
  final String cardId;
  final String? previousAttachmentId;
}

/// Pick any file, store it (routed to image/audio/file by its mime, §4.2), point
/// [cardId] at the new attachment, and GC the [previousAttachmentId] (if any).
class PickFileEffect extends CardEditEffect {
  const PickFileEffect({
    required this.cardId,
    required this.previousAttachmentId,
  });
  final String cardId;
  final String? previousAttachmentId;
}

/// Clear [cardId]'s attachment and GC the [previousAttachmentId].
class RemoveAttachmentEffect extends CardEditEffect {
  const RemoveAttachmentEffect({
    required this.cardId,
    required this.previousAttachmentId,
  });
  final String cardId;
  final String? previousAttachmentId;
}
