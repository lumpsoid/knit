import 'package:knit/core/attachments/domain/picked_image.dart';
import 'package:knit/features/collection/domain/collection_models.dart';
import 'package:knit/features/connections/domain/connections_models.dart';

/// Async-work descriptors for the Collection screen (fcis.md §6.4). Positions
/// are pre-computed by the (pure) updater and ride in the effect, so the shell
/// and write repo carry no ordering logic.
sealed class CollectionEffect {
  const CollectionEffect();
}

/// Read the header + ordered feed + link candidates (§8.7) for [collectionId].
class LoadCollectionEffect extends CollectionEffect {
  const LoadCollectionEffect(this.collectionId);
  final String collectionId;
}

/// Load the decoded bytes for an image card's [attachmentId] (§7.4.3) so the
/// feed can render the thumbnail. One per uncached image card.
class LoadImageBytesEffect extends CollectionEffect {
  const LoadImageBytesEffect(this.attachmentId);
  final String attachmentId;
}

/// Append a card of [kind] at [position] (§8.4). [text] is the body or URL.
class AddCardEffect extends CollectionEffect {
  const AddCardEffect({
    required this.collectionId,
    required this.kind,
    required this.position,
    this.text,
  });
  final String collectionId;
  final CardKind kind;
  final String position;
  final String? text;
}

/// Open the platform picker so the chosen image can be previewed in the
/// composer (the shell delivers the result back as an [ImagePicked] action).
class PickImageEffect extends CollectionEffect {
  const PickImageEffect();
}

/// Store the already-picked [image] (§7.4.8), then append an image card at
/// [position] carrying [caption] (the composer text, already trimmed; null when
/// blank). The attachment id is minted in the shell from [image] — unlike a
/// text/link [AddCardEffect], which carries no attachment.
class AddPhotoCardEffect extends CollectionEffect {
  const AddPhotoCardEffect({
    required this.collectionId,
    required this.position,
    required this.image,
    this.caption,
  });
  final String collectionId;
  final String position;
  final PickedImage image;
  final String? caption;
}

class DeleteCardEffect extends CollectionEffect {
  const DeleteCardEffect(this.cardId);
  final String cardId;
}

/// Share a card (§4.2). The updater resolves the card to its shareable content:
/// [text] is the body/caption (null when blank); [attachmentId] is set only for
/// an image card (the shell loads its bytes); [imageBaseName] is the date-stamped
/// file name stem (e.g. `2026-06-16-knit`), to which the shell appends the
/// extension once it knows the image's mime.
class ShareCardEffect extends CollectionEffect {
  const ShareCardEffect({
    this.text,
    this.attachmentId,
    required this.imageBaseName,
  });
  final String? text;
  final String? attachmentId;
  final String imageBaseName;
}

class ReorderCardEffect extends CollectionEffect {
  const ReorderCardEffect(this.cardId, this.position);
  final String cardId;
  final String position;
}

/// Load the finder's first level — the device's live collections (§4.4).
class LoadLinkCollectionsEffect extends CollectionEffect {
  const LoadLinkCollectionsEffect();
}

/// Load [collectionId]'s cards for the finder's drilled level (§4.4).
class LoadCollectionCardsEffect extends CollectionEffect {
  const LoadCollectionCardsEffect(this.collectionId);
  final String collectionId;
}

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

class EditTitleEffect extends CollectionEffect {
  const EditTitleEffect(this.collectionId, this.title);
  final String collectionId;
  final String title;
}
