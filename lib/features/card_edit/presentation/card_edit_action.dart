import 'package:knit/features/card_edit/domain/card_edit_models.dart';
import 'package:knit/features/collection/domain/collection_models.dart';
import 'package:knit/features/connections/domain/connections_models.dart';

/// Intents + async-result deliveries for the Card Edit page (fcis.md §6.4). All
/// payloads are scalars / view-models (no sync-core types).
sealed class CardEditAction {
  const CardEditAction();
}

/// View attached for [cardId], seeded with the text + attachment metadata from
/// the route-args carrier (cross_feature.md §2). Kicks off loading the card's
/// links and the picker target tree, and shows an image attachment.
class ViewAttached extends CardEditAction {
  const ViewAttached({
    required this.cardId,
    required this.initialText,
    required this.initialAttachmentId,
    this.initialAttachmentKind,
    this.initialFileName,
    this.initialFileSize,
  });
  final String cardId;
  final String initialText;
  final String? initialAttachmentId;
  final CardKind? initialAttachmentKind;
  final String? initialFileName;
  final int? initialFileSize;
}

/// Save tapped with the composed [text].
class SaveRequested extends CardEditAction {
  const SaveRequested(this.text);
  final String text;
}

/// The text write committed; the page pops (driven by a UI effect from the shell).
class SaveSucceeded extends CardEditAction {
  const SaveSucceeded();
}

/// The text write failed; stay on the page so the edit isn't lost.
class SaveFailed extends CardEditAction {
  const SaveFailed();
}

// --- links (subtask 3) -----------------------------------------------------

/// The card's outgoing links finished loading.
class LinksLoaded extends CardEditAction {
  const LinksLoaded(this.links);
  final List<ConnectionItem> links;
}

/// Loading the links failed — drop the spinner (the page shows an empty list).
class LinksLoadFailed extends CardEditAction {
  const LinksLoadFailed();
}

/// The picker target tree finished loading.
class TargetsLoaded extends CardEditAction {
  const TargetsLoaded(this.targets);
  final List<CardLinkCollectionTargets> targets;
}

/// Add a link from this card to the chosen target (collection or card).
class AddLinkRequested extends CardEditAction {
  const AddLinkRequested({required this.targetKind, required this.targetId});
  final ConnectedEntityKind targetKind;
  final String targetId;
}

/// Remove one of the card's links.
class RemoveLinkRequested extends CardEditAction {
  const RemoveLinkRequested(this.linkId);
  final String linkId;
}

/// A link was added/removed — reload the list.
class LinksChanged extends CardEditAction {
  const LinksChanged();
}

// --- attachment (subtask 4) ------------------------------------------------

/// Add or replace the card's attachment with a *photo* — opens the image picker
/// (gallery/camera), stores the bytes, points the card at the new attachment.
class PickImageRequested extends CardEditAction {
  const PickImageRequested();
}

/// Add or replace the card's attachment with *any file* — opens the platform
/// file picker; the chosen file is routed to image/audio/file by its mime (§4.2).
class PickFileRequested extends CardEditAction {
  const PickFileRequested();
}

/// Remove the card's attachment.
class RemoveAttachmentRequested extends CardEditAction {
  const RemoveAttachmentRequested();
}

/// The card's attachment settled to [attachmentId] (null = removed) after a
/// pick/remove, carrying the resolved [kind] and a file's [name]/[size] for its
/// chip (an image's bytes are in the shared image cache), so the section never
/// needs a follow-up reload.
class AttachmentResolved extends CardEditAction {
  const AttachmentResolved({
    this.attachmentId,
    this.kind,
    this.name,
    this.size,
  });
  final String? attachmentId;
  final CardKind? kind;
  final String? name;
  final int? size;
}

/// An attachment edit ended without changing anything (cancelled pick or
/// failure) — drop the busy flag, leave the current attachment in place.
class AttachmentEditEnded extends CardEditAction {
  const AttachmentEditEnded();
}

class DeactivateFeature extends CardEditAction {
  const DeactivateFeature();
}
