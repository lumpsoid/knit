import 'package:knit/core/attachments/domain/image_picker_port.dart';
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

/// Open the platform picker on [source] (camera or gallery) so the chosen image
/// can be previewed in the composer (the shell delivers the result back as an
/// [ImagePicked] action).
class PickImageEffect extends CollectionEffect {
  const PickImageEffect(this.source);
  final ImagePickerSource source;
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

/// Audio capture lifecycle (§4.2), each a thin call into the [AudioRecorderPort].
/// Start delivers an [AudioRecordingStarted]/[AudioRecordingStartFailed] action;
/// stop delivers an [AudioRecorded]; pause/resume/cancel are fire-and-forget
/// (the updater already moved the phase optimistically).
class StartAudioRecordingEffect extends CollectionEffect {
  const StartAudioRecordingEffect();
}

class PauseAudioRecordingEffect extends CollectionEffect {
  const PauseAudioRecordingEffect();
}

class ResumeAudioRecordingEffect extends CollectionEffect {
  const ResumeAudioRecordingEffect();
}

class StopAudioRecordingEffect extends CollectionEffect {
  const StopAudioRecordingEffect();
}

class CancelAudioRecordingEffect extends CollectionEffect {
  const CancelAudioRecordingEffect();
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
  });
  final String collectionId;
  final String position;
  final PickedAudio audio;
  final String? caption;
}

/// Open the platform file picker so the chosen file can be previewed in the
/// composer (the shell delivers the result back as a [FilePicked] action).
class PickFileEffect extends CollectionEffect {
  const PickFileEffect();
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
  });
  final String collectionId;
  final String position;
  final PickedFile file;
  final String? caption;
}

class DeleteCardEffect extends CollectionEffect {
  const DeleteCardEffect(this.cardId);
  final String cardId;
}

/// Share a card (§4.2). The updater resolves the card to its shareable content:
/// [text] is the body/caption (null when blank); [attachmentId] is set for an
/// image or file card (the shell loads its bytes). For a file card [fileName]
/// is its stored name, used verbatim; for an image card [fileName] is null and
/// the shell builds a date-stamped name from [imageBaseName] + the image mime.
class ShareCardEffect extends CollectionEffect {
  const ShareCardEffect({
    this.text,
    this.attachmentId,
    required this.imageBaseName,
    this.fileName,
  });
  final String? text;
  final String? attachmentId;
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
