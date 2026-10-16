import 'package:effect_emitter/effect_emitter.dart';
import 'package:fcis_core/fcis_core.dart';
import 'package:logging/logging.dart';
import 'package:result_dart/result_dart.dart';
import 'package:knit/core/attachments/domain/attachment_read_repository.dart';
import 'package:knit/core/attachments/domain/attachment_write_repository.dart';
import 'package:knit/core/attachments/domain/audio_recorder_port.dart';
import 'package:knit/core/attachments/domain/file_picker_port.dart';
import 'package:knit/core/attachments/domain/image_picker_port.dart';
import 'package:knit/core/attachments/domain/picked_audio.dart';
import 'package:knit/core/attachments/domain/picked_file.dart';
import 'package:knit/core/attachments/domain/picked_image.dart';
import 'package:knit/core/attachments/presentation/attachment_image_cache.dart';
import 'package:knit/features/collection/domain/card_share_repository.dart';
import 'package:knit/features/collection/domain/collection_failure.dart';
import 'package:knit/features/collection/domain/collection_models.dart';
import 'package:knit/features/collection/domain/collection_read_repository.dart';
import 'package:knit/features/collection/domain/collection_write_repository.dart';
import 'package:knit/features/collection/domain/link_launcher.dart';
import 'package:knit/features/collection_details/domain/collection_details.dart';
import 'package:knit/features/collection_details/presentation/collection_details_controller.dart';
import 'package:knit/features/timeline/domain/timeline_channel.dart';
import 'package:knit/features/collection/presentation/collection_action.dart';
import 'package:knit/features/collection/presentation/collection_effect.dart';
import 'package:knit/features/collection/presentation/collection_ui_effect.dart';

/// Imperative shell for the Collection screen (fcis.md §6.6). Unwraps each
/// repository [Result] at the seam (result.md §9.3) into a success/failure
/// Action; the updater never sees a Result. Every successful write re-reads the
/// feed (via [ReloadRequested]) so the projection — not the optimistic local
/// list — is the source of truth; a failed write surfaces a message and still
/// resyncs.
class CollectionShell extends Shell<CollectionEffect, CollectionAction> {
  CollectionShell({
    required CollectionReadRepository readRepository,
    required CollectionWriteRepository writeRepository,
    required AttachmentReadRepository attachmentReadRepository,
    required AttachmentWriteRepository attachmentWriteRepository,
    required AttachmentImageCache imageCache,
    required ImagePickerPort imagePicker,
    required AudioRecorderPort audioRecorder,
    required FilePickerPort filePicker,
    required CardShareRepository shareRepository,
    required LinkLauncher linkLauncher,
    required CollectionDetailsController collectionDetails,
    required EffectEmitter<CollectionUiEffect> effectEmitter,
    required TimelineChannelEmitter timelineChannel,
    required Logger logger,
  }) : _read = readRepository,
       _write = writeRepository,
       _attachmentRead = attachmentReadRepository,
       _attachmentWrite = attachmentWriteRepository,
       _images = imageCache,
       _picker = imagePicker,
       _recorder = audioRecorder,
       _filePicker = filePicker,
       _share = shareRepository,
       _links = linkLauncher,
       _details = collectionDetails,
       _effectEmitter = effectEmitter,
       _timelineChannel = timelineChannel,
       _log = logger;

  final CollectionReadRepository _read;
  final CollectionWriteRepository _write;
  final AttachmentReadRepository _attachmentRead;
  final AttachmentWriteRepository _attachmentWrite;
  final AttachmentImageCache _images;
  final ImagePickerPort _picker;
  final AudioRecorderPort _recorder;
  final FilePickerPort _filePicker;
  final CardShareRepository _share;
  final LinkLauncher _links;
  final CollectionDetailsController _details;
  final EffectEmitter<CollectionUiEffect> _effectEmitter;
  final TimelineChannelEmitter _timelineChannel;
  final Logger _log;

  /// This page's owner tokens in the shared image cache: the feed window's
  /// images and the title card's cover are shown independently.
  final Object _feedImages = Object();
  final Object _coverImage = Object();

  @override
  Future<void> run(
    CollectionEffect effect, {
    required void Function(CollectionAction) dispatch,
  }) async {
    switch (effect) {
      case LoadCollectionEffect(:final collectionId, :final window):
        final result = await _read.loadCollection(collectionId, window: window);
        result.onTap(
          (data) {
            // The header is shared app-wide state: refresh it from this read.
            _details.remember(
              CollectionDetails(
                collectionId: data.collectionId,
                title: data.title,
                description: data.description,
                coverAttachmentId: data.coverAttachmentId,
              ),
            );
            dispatch(CollectionLoaded(data));
          },
          (failure) {
            _log.severe(
              'Collection load failed',
              failure.error,
              failure.stackTrace,
            );
            dispatch(const LoadFailed());
          },
        );

      case LoadOlderCardsEffect(
        :final collectionId,
        :final before,
        :final limit,
      ):
        final result = await _read.loadOlderCards(
          collectionId,
          before: before,
          limit: limit,
        );
        result.onTap((page) => dispatch(OlderCardsLoaded(before, page)), (
          failure,
        ) {
          _log.severe(
            'Older cards load failed',
            failure.error,
            failure.stackTrace,
          );
          dispatch(const OlderCardsLoadFailed());
        });

      case ShowFeedImagesEffect(:final attachmentIds):
        await _images.show(_feedImages, attachmentIds);

      case ShowCoverEffect(:final attachmentId):
        await _images.show(_coverImage, [?attachmentId]);

      case ReleaseImagesEffect():
        _images
          ..release(_feedImages)
          ..release(_coverImage);

      case AddCardEffect(
        :final collectionId,
        :final kind,
        :final position,
        :final text,
      ):
        await _runWrite(
          () => _write.addCard(
            collectionId: collectionId,
            kind: kind,
            position: position,
            text: text,
          ),
          'add card',
          dispatch,
        );

      case PickImageEffect(:final source):
        final picked = await _picker.pickImage(source: source);
        dispatch(ImagePicked(picked));

      case AddPhotoCardEffect(
        :final collectionId,
        :final position,
        :final image,
        :final caption,
      ):
        await _addPhotoCard(collectionId, position, image, caption, dispatch);

      case StartAudioRecordingEffect():
        await _startRecording(dispatch);

      case PauseAudioRecordingEffect():
        await _safeRecorder(() => _recorder.pause(), 'pause recording');

      case ResumeAudioRecordingEffect():
        await _safeRecorder(() => _recorder.resume(), 'resume recording');

      case StopAudioRecordingEffect():
        await _stopRecording(dispatch);

      case CancelAudioRecordingEffect():
        await _safeRecorder(() => _recorder.cancel(), 'cancel recording');

      case AddAudioCardEffect(
        :final collectionId,
        :final position,
        :final audio,
        :final caption,
      ):
        await _addAudioCard(collectionId, position, audio, caption, dispatch);

      case PickFileEffect():
        final picked = await _filePicker.pickFile();
        dispatch(FilePicked(picked));

      case AddFileCardEffect(
        :final collectionId,
        :final position,
        :final file,
        :final caption,
      ):
        await _addFileCard(collectionId, position, file, caption, dispatch);

      case DeleteCardEffect(:final cardId, :final attachmentId):
        await _runWrite(
          () => _write.deleteCard(cardId),
          'delete card',
          dispatch,
          onSuccess: () => _gcDeletedCardAttachment(attachmentId),
        );

      case ShareCardEffect(
        :final text,
        :final attachmentId,
        :final imageBaseName,
        :final fileName,
      ):
        await _shareCard(text, attachmentId, imageBaseName, fileName);

      case OpenLinkEffect(:final url):
        await _openLink(url);

      case ReorderCardEffect(:final cardId, :final position):
        await _runWrite(
          () => _write.reorderCard(cardId, position),
          'reorder card',
          dispatch,
        );

      case LoadLinkCollectionsEffect():
        final result = await _read.loadLinkCollections();
        result.onTap((options) => dispatch(LinkCollectionsLoaded(options)), (
          failure,
        ) {
          _log.severe(
            'Link collections load failed',
            failure.error,
            failure.stackTrace,
          );
          dispatch(const LinkCollectionsLoaded([]));
        });

      case LoadCollectionCardsEffect(:final collectionId):
        final result = await _read.loadCollectionCards(collectionId);
        result.onTap(
          (options) => dispatch(LinkCardsLoaded(collectionId, options)),
          (failure) {
            _log.severe(
              'Link cards load failed',
              failure.error,
              failure.stackTrace,
            );
            dispatch(LinkCardsLoaded(collectionId, const []));
          },
        );

      case LinkEffect(:final cardId, :final targetKind, :final targetId):
        await _runWrite(
          () => _write.linkCardToTarget(
            cardId: cardId,
            targetKind: targetKind,
            targetId: targetId,
          ),
          'create link',
          dispatch,
        );
    }
  }

  /// Store the already-picked [image] (content-addressed, §7.4.8), then append
  /// an image card carrying [caption] and resync. The preview was cleared
  /// optimistically by the updater on send; a store/write failure surfaces a
  /// message and still resyncs, matching the text/link write path.
  Future<void> _addPhotoCard(
    String collectionId,
    String position,
    PickedImage image,
    String? caption,
    void Function(CollectionAction) dispatch,
  ) async {
    final created = await _attachmentWrite.createFromPicked(image);
    if (created.isFailure) {
      _log.severe('Store picked image failed', created.error);
      _effectEmitter.push(
        const CollectionShowMessageUiEffect(CollectionMessage.saveFailed),
      );
      dispatch(const ReloadRequested());
      return;
    }
    // The bytes are in hand: seed the shared cache so the new card renders
    // without reading them back.
    _images.put(created.getOrThrow(), image.bytes);

    await _runWrite(
      () => _write.addCard(
        collectionId: collectionId,
        kind: CardKind.image,
        position: position,
        text: caption,
        attachmentId: created.getOrThrow(),
      ),
      'add photo card',
      dispatch,
    );
  }

  /// Begin capturing an audio message. A clean start delivers
  /// [AudioRecordingStarted]; a denied microphone permission (or an error)
  /// surfaces a message and delivers [AudioRecordingStartFailed] so the bar
  /// returns to idle.
  Future<void> _startRecording(void Function(CollectionAction) dispatch) async {
    try {
      if (await _recorder.start()) {
        dispatch(const AudioRecordingStarted());
      } else {
        _effectEmitter.push(
          const CollectionShowMessageUiEffect(
            CollectionMessage.micPermissionDenied,
          ),
        );
        dispatch(const AudioRecordingStartFailed());
      }
    } catch (e, s) {
      _log.severe('Start audio recording failed', e, s);
      _effectEmitter.push(
        const CollectionShowMessageUiEffect(CollectionMessage.saveFailed),
      );
      dispatch(const AudioRecordingStartFailed());
    }
  }

  /// Stop capturing and deliver the clip (null on failure/empty — the updater
  /// then just leaves recording mode). A failure surfaces a message.
  Future<void> _stopRecording(void Function(CollectionAction) dispatch) async {
    try {
      dispatch(AudioRecorded(await _recorder.stop()));
    } catch (e, s) {
      _log.severe('Stop audio recording failed', e, s);
      _effectEmitter.push(
        const CollectionShowMessageUiEffect(CollectionMessage.saveFailed),
      );
      dispatch(const AudioRecorded(null));
    }
  }

  /// Run a fire-and-forget recorder call (pause/resume/cancel); the phase was
  /// already moved optimistically, so a failure is logged only.
  Future<void> _safeRecorder(Future<void> Function() op, String label) async {
    try {
      await op();
    } catch (e, s) {
      _log.severe('Audio $label failed', e, s);
    }
  }

  /// Store the recorded [audio] (content-addressed, §7.4.8), then append an audio
  /// card carrying [caption] and resync — the audio twin of [_addPhotoCard].
  Future<void> _addAudioCard(
    String collectionId,
    String position,
    PickedAudio audio,
    String? caption,
    void Function(CollectionAction) dispatch,
  ) async {
    final created = await _attachmentWrite.createFromAudio(audio);
    if (created.isFailure) {
      _log.severe('Store recorded audio failed', created.error);
      _effectEmitter.push(
        const CollectionShowMessageUiEffect(CollectionMessage.saveFailed),
      );
      dispatch(const ReloadRequested());
      return;
    }

    await _runWrite(
      () => _write.addCard(
        collectionId: collectionId,
        kind: CardKind.audio,
        position: position,
        text: caption,
        attachmentId: created.getOrThrow(),
      ),
      'add audio card',
      dispatch,
    );
  }

  /// Store the picked [file] (content-addressed, §7.4.8), then append a file card
  /// carrying [caption] and resync — the file twin of [_addPhotoCard].
  Future<void> _addFileCard(
    String collectionId,
    String position,
    PickedFile file,
    String? caption,
    void Function(CollectionAction) dispatch,
  ) async {
    final created = await _attachmentWrite.createFromFile(file);
    if (created.isFailure) {
      _log.severe('Store picked file failed', created.error);
      _effectEmitter.push(
        const CollectionShowMessageUiEffect(CollectionMessage.saveFailed),
      );
      dispatch(const ReloadRequested());
      return;
    }

    await _runWrite(
      () => _write.addCard(
        collectionId: collectionId,
        kind: CardKind.file,
        position: position,
        text: caption,
        attachmentId: created.getOrThrow(),
      ),
      'add file card',
      dispatch,
    );
  }

  /// Share a card through the [CardShareRepository] (§4.2). For an image or file
  /// card, resolve its bytes via the attachment read port: a file shares under
  /// its stored [fileName]; an image builds a date-stamped name from
  /// [imageBaseName] + the mime the blob store recorded. If the bytes are gone,
  /// fall back to sharing the caption alone. Sharing is a read-only side-effect —
  /// it triggers no resync; a failure is logged only.
  Future<void> _shareCard(
    String? text,
    String? attachmentId,
    String imageBaseName,
    String? fileName,
  ) async {
    ShareableImage? image;
    if (attachmentId != null) {
      final result = await _attachmentRead.bytesOf(attachmentId);
      if (result.isFailure) {
        _log.warning('Share: attachment bytes missing for $attachmentId');
      } else {
        final bytes = result.getOrThrow();
        image = fileName != null
            ? ShareableImage(
                bytes: bytes.bytes,
                mime: bytes.mime,
                fileName: fileName,
              )
            : ShareableImage.named(
                bytes: bytes.bytes,
                mime: bytes.mime,
                baseName: imageBaseName,
              );
      }
    }
    // The attachment may have vanished from a text-less card — nothing to share.
    if (text == null && image == null) return;
    final shared = await _share.share(ShareableCard(text: text, image: image));
    shared.onFailure(
      (failure) =>
          _log.severe('Share card failed', failure.error, failure.stackTrace),
    );
  }

  /// Open [url] in the browser through the [LinkLauncher] port. Opening is a
  /// read-only side-effect — it triggers no resync; a failure (unlaunchable URL
  /// or no platform handler) is logged and surfaced as a message.
  Future<void> _openLink(String url) async {
    final opened = await _links.open(url);
    opened.onFailure((failure) {
      _log.severe('Open link failed', failure.error, failure.stackTrace);
      _effectEmitter.push(
        const CollectionShowMessageUiEffect(CollectionMessage.linkOpenFailed),
      );
    });
  }

  /// Run a write, then resync from the projection. On failure, surface a
  /// message and still resync (drops any optimistic local change). [onSuccess],
  /// when given, runs on the success branch *before* the resync — used to
  /// reclaim any storage the write freed (e.g. a deleted card's attachment).
  Future<void> _runWrite(
    Future<Result<String, CollectionFailure>> Function() op,
    String label,
    void Function(CollectionAction) dispatch, {
    Future<void> Function()? onSuccess,
  }) async {
    final result = await op();
    await result.foldAsync(
      (_) async {
        if (onSuccess != null) await onSuccess();
        // The write changed the home timeline too (title, last-card preview,
        // count, updated-time). Nudge the Timeline to re-read via its input
        // channel (cross_feature.md §3) — it's mounted underneath this page.
        _timelineChannel.emit(const RefreshChannelEvent());
        dispatch(const ReloadRequested());
      },
      (failure) async {
        _log.severe(
          'Collection $label failed',
          failure.error,
          failure.stackTrace,
        );
        _effectEmitter.push(
          const CollectionShowMessageUiEffect(CollectionMessage.saveFailed),
        );
        dispatch(const ReloadRequested());
      },
    );
  }

  /// Reclaim the attachment a just-deleted card uniquely owned — but only when
  /// no other live card still references it, so a legacy shared record (created
  /// before the 1 referent : 1 record invariant) is never orphaned. The
  /// ref-counted blob GC inside [AttachmentWriteRepository.delete] then keeps the
  /// blob for any sibling *record* sharing the bytes. Conservative on an unknown
  /// reference state, and non-fatal on failure — the card is already gone; this
  /// only reclaims storage.
  Future<void> _gcDeletedCardAttachment(String? attachmentId) async {
    if (attachmentId == null) return;
    final check = await _read.isAttachmentReferenced(attachmentId);
    // Skip GC when still referenced, or when the check failed (don't risk an
    // orphan on an unknown reference state).
    if (check.isFailure || check.getOrThrow()) return;
    final result = await _attachmentWrite.delete(attachmentId);
    if (result.isFailure) {
      _log.warning('Attachment GC failed for $attachmentId: ${result.error}');
    }
  }
}
