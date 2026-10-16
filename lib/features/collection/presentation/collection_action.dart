import 'package:knit/core/attachments/domain/image_picker_port.dart';
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

/// Bottom composer submitted a quick text card (§4.2).
class ComposerSubmitted extends CollectionAction {
  const ComposerSubmitted(this.text);
  final String text;
}

/// The "+" add-block finder submitted a standalone link card (§4.2).
class LinkCardSubmitted extends CollectionAction {
  const LinkCardSubmitted(this.url);
  final String url;
}

/// The photo-source options chose a [source] (§4.2): open the picker (camera or
/// gallery) so the chosen image can be previewed above the composer before it
/// becomes a card.
class PickImageRequested extends CollectionAction {
  const PickImageRequested(this.source);
  final ImagePickerSource source;
}

/// Delivery of [PickImageRequested]: the picker returned [image] (null when the
/// user cancelled). A non-null image becomes the composer's pending preview.
class ImagePicked extends CollectionAction {
  const ImagePicked(this.image);
  final PickedImage? image;
}

/// The preview's clear ("✕") button — drop the pending image without writing
/// anything. The user can then send text only, or pick a different image.
class PendingImageCleared extends CollectionAction {
  const PendingImageCleared();
}

/// The audio bar's "Start recording" button (§4.2): begin capturing. The phase
/// is staged only once the shell confirms the recorder started ([AudioRecordingStarted]).
class AudioRecordingRequested extends CollectionAction {
  const AudioRecordingRequested();
}

/// Delivery of [AudioRecordingRequested]: the recorder began capturing.
class AudioRecordingStarted extends CollectionAction {
  const AudioRecordingStarted();
}

/// Delivery of [AudioRecordingRequested]: the recorder couldn't start (e.g.
/// microphone permission denied). The bar returns to idle; the shell messages.
class AudioRecordingStartFailed extends CollectionAction {
  const AudioRecordingStartFailed();
}

/// The recording controls' "Pause"/"Resume" buttons (§4.2). Optimistic: the
/// phase flips immediately and the shell tells the recorder.
class AudioRecordingPauseRequested extends CollectionAction {
  const AudioRecordingPauseRequested();
}

class AudioRecordingResumeRequested extends CollectionAction {
  const AudioRecordingResumeRequested();
}

/// The recording controls' "Stop" button (§4.2): finish capturing. The shell
/// reads back the clip and delivers it as [AudioRecorded].
class AudioRecordingStopRequested extends CollectionAction {
  const AudioRecordingStopRequested();
}

/// Delivery of [AudioRecordingStopRequested]: the recorder returned [audio]
/// (null when nothing was captured). A non-null clip becomes the pending preview.
class AudioRecorded extends CollectionAction {
  const AudioRecorded(this.audio);
  final PickedAudio? audio;
}

/// Back out of an in-flight recording (the audio bar's "✕"): discard it without
/// writing anything. A no-op for the recorder if nothing is recording.
class AudioRecordingCancelled extends CollectionAction {
  const AudioRecordingCancelled();
}

/// The pending audio preview's clear ("✕") button — drop the recorded-but-unsent
/// clip without writing anything (the recorder has already stopped).
class PendingAudioCleared extends CollectionAction {
  const PendingAudioCleared();
}

/// The "+" add-block chose File (§4.2): open the platform file picker so the
/// chosen file can be previewed above the composer before it becomes a card.
class PickFileRequested extends CollectionAction {
  const PickFileRequested();
}

/// Delivery of [PickFileRequested]: the picker returned [file] (null when the
/// user cancelled). A non-null file becomes the composer's pending preview.
class FilePicked extends CollectionAction {
  const FilePicked(this.file);
  final PickedFile? file;
}

/// The pending-file preview's clear ("✕") button — drop the picked-but-unsent
/// file without writing anything (the file twin of [PendingImageCleared]).
class PendingFileCleared extends CollectionAction {
  const PendingFileCleared();
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

/// Tapped a link card's URL → open it in the system browser (§4.2). The updater
/// resolves the card to its stored link text and emits the open effect; the
/// launch itself lives behind the LinkLauncher port.
class LinkCardOpened extends CollectionAction {
  const LinkCardOpened(this.cardId);
  final String cardId;
}

/// Actions sheet → "Make a link" opened the finder (§4.4). Loads the first
/// level (collections); a no-op if they are already loaded is fine — it just
/// refreshes them.
class LinkFinderOpened extends CollectionAction {
  const LinkFinderOpened();
}

/// Finder drilled into [collectionId] to browse its cards. Triggers a lazy
/// card load on cache miss; a cache hit is a pure no-op.
class LinkCollectionOpened extends CollectionAction {
  const LinkCollectionOpened(this.collectionId);
  final String collectionId;
}

/// The finder's first level finished loading (delivery of [LinkFinderOpened]).
class LinkCollectionsLoaded extends CollectionAction {
  const LinkCollectionsLoaded(this.collections);
  final List<LinkOption> collections;
}

/// A collection's cards finished loading (delivery of [LinkCollectionOpened]).
class LinkCardsLoaded extends CollectionAction {
  const LinkCardsLoaded(this.collectionId, this.cards);
  final String collectionId;
  final List<LinkOption> cards;
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

class DeactivateFeature extends CollectionAction {
  const DeactivateFeature();
}
