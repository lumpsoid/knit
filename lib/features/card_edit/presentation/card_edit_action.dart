import 'dart:typed_data';

import 'package:knit/features/card_edit/domain/card_edit_models.dart';
import 'package:knit/features/connections/domain/connections_models.dart';

/// Intents + async-result deliveries for the Card Edit page (fcis.md §6.4). All
/// payloads are scalars / view-models (no sync-core types).
sealed class CardEditAction {
  const CardEditAction();
}

/// View attached for [cardId], seeded with [initialText] + [initialAttachmentId]
/// from the route-args carrier (cross_feature.md §2). Kicks off loading the
/// card's links, the picker target tree, and the current image bytes.
class ViewAttached extends CardEditAction {
  const ViewAttached({
    required this.cardId,
    required this.initialText,
    required this.initialAttachmentId,
  });
  final String cardId;
  final String initialText;
  final String? initialAttachmentId;
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

// --- image (subtask 4) -----------------------------------------------------

/// Add or replace the card's image — opens the picker, stores the bytes, points
/// the card at the new attachment.
class PickImageRequested extends CardEditAction {
  const PickImageRequested();
}

/// Remove the card's image.
class RemoveImageRequested extends CardEditAction {
  const RemoveImageRequested();
}

/// The card's image changed to [attachmentId] (null = removed). Triggers a bytes
/// load when non-null.
class ImageChanged extends CardEditAction {
  const ImageChanged(this.attachmentId);
  final String? attachmentId;
}

/// The image's decoded bytes finished loading (null = none/failed).
class ImageBytesLoaded extends CardEditAction {
  const ImageBytesLoaded(this.bytes);
  final Uint8List? bytes;
}

/// An image edit ended without changing anything (cancelled pick or failure) —
/// drop the busy flag.
class ImageEditEnded extends CardEditAction {
  const ImageEditEnded();
}

class DeactivateFeature extends CardEditAction {
  const DeactivateFeature();
}
