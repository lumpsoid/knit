import 'package:effect_emitter/effect_emitter.dart';
import 'package:fcis_core/fcis_core.dart';
import 'package:logging/logging.dart';
import 'package:result_dart/result_dart.dart';
import 'package:knit/core/attachments/domain/attachment_read_repository.dart';
import 'package:knit/core/attachments/domain/attachment_write_repository.dart';
import 'package:knit/core/attachments/domain/picked_audio.dart';
import 'package:knit/core/attachments/domain/picked_file.dart';
import 'package:knit/core/attachments/domain/picked_image.dart';
import 'package:knit/core/attachments/presentation/attachment_image_cache.dart';
import 'package:knit/features/collection/domain/card_move_read_repository.dart';
import 'package:knit/features/collection/domain/card_share_repository.dart';
import 'package:knit/features/collection/domain/collection_failure.dart';
import 'package:knit/features/collection/domain/collection_models.dart';
import 'package:knit/features/collection/domain/collection_outline_read_repository.dart';
import 'package:knit/features/collection/domain/collection_read_repository.dart';
import 'package:knit/features/collection/domain/collection_write_repository.dart';
import 'package:knit/features/collection/domain/link_launcher.dart';
import 'package:knit/features/card_links/presentation/card_links_controller.dart';
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
    required CardMoveReadRepository moveReadRepository,
    required CollectionOutlineReadRepository outlineReadRepository,
    required AttachmentReadRepository attachmentReadRepository,
    required AttachmentWriteRepository attachmentWriteRepository,
    required AttachmentImageCache imageCache,
    required CardShareRepository shareRepository,
    required LinkLauncher linkLauncher,
    required CollectionDetailsController collectionDetails,
    required CardLinksController cardLinks,
    required EffectEmitter<CollectionUiEffect> effectEmitter,
    required TimelineChannelEmitter timelineChannel,
    required Logger logger,
  }) : _read = readRepository,
       _write = writeRepository,
       _moveRead = moveReadRepository,
       _outlineRead = outlineReadRepository,
       _attachmentRead = attachmentReadRepository,
       _attachmentWrite = attachmentWriteRepository,
       _images = imageCache,
       _share = shareRepository,
       _links = linkLauncher,
       _details = collectionDetails,
       _cardLinks = cardLinks,
       _effectEmitter = effectEmitter,
       _timelineChannel = timelineChannel,
       _log = logger;

  final CollectionReadRepository _read;
  final CollectionWriteRepository _write;
  final CardMoveReadRepository _moveRead;
  final CollectionOutlineReadRepository _outlineRead;
  final AttachmentReadRepository _attachmentRead;
  final AttachmentWriteRepository _attachmentWrite;
  final AttachmentImageCache _images;
  final CardShareRepository _share;
  final LinkLauncher _links;
  final CollectionDetailsController _details;
  final CardLinksController _cardLinks;
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

      case LoadOutlineEffect(:final collectionId):
        final result = await _outlineRead.loadOutlineCards(collectionId);
        result.onTap((cards) => dispatch(OutlineCardsLoaded(cards)), (failure) {
          _log.severe('Outline load failed', failure.error, failure.stackTrace);
          dispatch(const OutlineLoadFailed());
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
        :final closesQuickInput,
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
          onSuccess: _quickInputCloser(closesQuickInput),
        );

      case AddPhotoCardEffect(
        :final collectionId,
        :final position,
        :final images,
        :final caption,
        :final closesQuickInput,
      ):
        await _addPhotoCard(
          collectionId,
          position,
          images,
          caption,
          dispatch,
          onSuccess: _quickInputCloser(closesQuickInput),
        );

      case AddAudioCardEffect(
        :final collectionId,
        :final position,
        :final audio,
        :final caption,
        :final closesQuickInput,
      ):
        await _addAudioCard(
          collectionId,
          position,
          audio,
          caption,
          dispatch,
          onSuccess: _quickInputCloser(closesQuickInput),
        );

      case AddFileCardEffect(
        :final collectionId,
        :final position,
        :final file,
        :final caption,
        :final closesQuickInput,
      ):
        await _addFileCard(
          collectionId,
          position,
          file,
          caption,
          dispatch,
          onSuccess: _quickInputCloser(closesQuickInput),
        );

      case DeleteCardEffect(:final cardId, :final attachmentIds):
        await _runWrite(
          () => _write.deleteCard(cardId),
          'delete card',
          dispatch,
          onSuccess: () async {
            for (final id in attachmentIds) {
              await _gcDeletedCardAttachment(id);
            }
          },
        );

      case DeleteCollectionEffect(:final collectionId):
        final result = await _write.deleteCollection(collectionId);
        result.onTap(
          (id) {
            // The Timeline reloads and drops the pin; the page closes.
            _timelineChannel.emit(CollectionDeletedChannelEvent(id));
            _effectEmitter.push(const CollectionDeletedUiEffect());
          },
          (failure) {
            _log.severe(
              'Collection delete failed',
              failure.error,
              failure.stackTrace,
            );
            _effectEmitter.push(
              const CollectionShowMessageUiEffect(
                CollectionMessage.deleteFailed,
              ),
            );
          },
        );

      case DeleteCardsEffect(:final cardIds, :final attachmentIds):
        await _runWrite(
          () => _write.deleteCards(cardIds),
          'delete cards',
          dispatch,
          onSuccess: () async {
            for (final id in attachmentIds) {
              await _gcDeletedCardAttachment(id);
            }
          },
        );

      case ShareCardEffect(
        :final text,
        :final attachmentIds,
        :final imageBaseName,
        :final fileName,
      ):
        await _shareCard(text, attachmentIds, imageBaseName, fileName);

      case OpenLinkEffect(:final url):
        await _openLink(url);

      case SettleCardsEffect(:final cardIds, :final settled):
        await _runWrite(
          () => _write.setCardsSettled(cardIds, settled: settled),
          settled ? 'settle cards' : 'unsettle cards',
          dispatch,
        );

      case EmphasizeCardsEffect(:final cardIds, :final emphasized):
        await _runWrite(
          () => _write.setCardsEmphasized(cardIds, emphasized: emphasized),
          emphasized ? 'emphasize cards' : 'unemphasize cards',
          dispatch,
        );

      case ReorderCardEffect(:final cardId, :final position):
        await _runWrite(
          () => _write.reorderCard(cardId, position),
          'reorder card',
          dispatch,
        );

      case LinkEffect(:final cardId, :final targetKind, :final targetId):
        await _runWrite(
          () async =>
              (await _cardLinks.link(
                sourceCardId: cardId,
                targetKind: targetKind,
                targetId: targetId,
              )).fold(
                Ok.new,
                (f) => Failure(CollectionWriteFailure(f.error, f.stackTrace)),
              ),
          'create link',
          dispatch,
        );

      case LoadMoveTargetsEffect():
        final result = await _moveRead.loadMoveTargets();
        result.onTap((targets) => dispatch(MoveTargetsLoaded(targets)), (
          failure,
        ) {
          _log.severe(
            'Move targets load failed',
            failure.error,
            failure.stackTrace,
          );
          dispatch(const MoveTargetsLoadFailed());
        });

      case LoadMoveTargetTailEffect(:final target):
        final result = await _moveRead.lastCardPosition(target.collectionId);
        result.onTap(
          (position) => dispatch(MoveTargetTailLoaded(target, position)),
          (failure) {
            _log.severe(
              'Move target read failed',
              failure.error,
              failure.stackTrace,
            );
            _effectEmitter.push(
              const CollectionShowMessageUiEffect(CollectionMessage.saveFailed),
            );
          },
        );

      case CreateMoveTargetEffect(:final title):
        final result = await _write.createCollection(title);
        result.onTap(
          (id) {
            // Home shows the new collection even if the move then fails.
            _timelineChannel.emit(const RefreshChannelEvent());
            dispatch(
              MoveTargetTailLoaded(
                MoveTarget(collectionId: id, title: title),
                null,
              ),
            );
          },
          (failure) {
            _log.severe(
              'Move target create failed',
              failure.error,
              failure.stackTrace,
            );
            _effectEmitter.push(
              const CollectionShowMessageUiEffect(CollectionMessage.saveFailed),
            );
          },
        );

      case MoveCardsEffect(:final target, :final positions):
        await _runWrite(
          () => _write.moveCards(target.collectionId, positions),
          'move cards',
          dispatch,
          onSuccess: () async => _effectEmitter.push(
            CollectionCardsMovedUiEffect(
              count: positions.length,
              targetCollectionId: target.collectionId,
              targetTitle: target.title,
            ),
          ),
        );
    }
  }

  /// Store the already-picked [images] (content-addressed, §7.4.8), then
  /// append one image card holding them in order (§4.2), carrying [caption],
  /// and resync. The preview was cleared
  /// optimistically by the updater on send; a store/write failure surfaces a
  /// message and still resyncs, matching the text/link write path.
  Future<void> _addPhotoCard(
    String collectionId,
    String position,
    List<PickedImage> images,
    String? caption,
    void Function(CollectionAction) dispatch, {
    Future<void> Function()? onSuccess,
  }) async {
    final ids = <String>[];
    for (final image in images) {
      final created = await _attachmentWrite.createFromPicked(image);
      if (created.isFailure) {
        _log.severe('Store picked image failed', created.error);
        // The card is never written: drop the photos already stored.
        for (final id in ids) {
          await _attachmentWrite.delete(id);
        }
        _effectEmitter.push(
          const CollectionShowMessageUiEffect(CollectionMessage.saveFailed),
        );
        dispatch(const ReloadRequested());
        return;
      }
      // The bytes are in hand: seed the shared cache so the new card renders
      // without reading them back.
      _images.put(created.getOrThrow(), image.bytes);
      ids.add(created.getOrThrow());
    }

    await _runWrite(
      () => _write.addCard(
        collectionId: collectionId,
        kind: CardKind.image,
        position: position,
        text: caption,
        attachmentId: ids.first,
        moreAttachmentIds: ids.sublist(1),
      ),
      'add photo card',
      dispatch,
      onSuccess: onSuccess,
    );
  }

  /// Store the recorded [audio] (content-addressed, §7.4.8), then append an audio
  /// card carrying [caption] and resync — the audio twin of [_addPhotoCard].
  Future<void> _addAudioCard(
    String collectionId,
    String position,
    PickedAudio audio,
    String? caption,
    void Function(CollectionAction) dispatch, {
    Future<void> Function()? onSuccess,
  }) async {
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
      onSuccess: onSuccess,
    );
  }

  /// Store the picked [file] (content-addressed, §7.4.8), then append a file card
  /// carrying [caption] and resync — the file twin of [_addPhotoCard].
  Future<void> _addFileCard(
    String collectionId,
    String position,
    PickedFile file,
    String? caption,
    void Function(CollectionAction) dispatch, {
    Future<void> Function()? onSuccess,
  }) async {
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
      onSuccess: onSuccess,
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
    List<String> attachmentIds,
    String imageBaseName,
    String? fileName,
  ) async {
    final files = <ShareableImage>[];
    for (final (index, attachmentId) in attachmentIds.indexed) {
      final result = await _attachmentRead.bytesOf(attachmentId);
      if (result.isFailure) {
        _log.warning('Share: attachment bytes missing for $attachmentId');
        continue;
      }
      final bytes = result.getOrThrow();
      files.add(
        fileName != null
            ? ShareableImage(
                bytes: bytes.bytes,
                mime: bytes.mime,
                fileName: fileName,
              )
            : ShareableImage.named(
                bytes: bytes.bytes,
                mime: bytes.mime,
                // Several photos get numbered names, so none overwrites another.
                baseName: attachmentIds.length == 1
                    ? imageBaseName
                    : '$imageBaseName-${index + 1}',
              ),
      );
    }
    // The attachments may have vanished from a text-less card — nothing to
    // share.
    if (text == null && files.isEmpty) return;
    final shared = await _share.share(ShareableCard(text: text, files: files));
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
  /// The [_runWrite] success step that leaves a quick-input page, or null
  /// for an ordinary send.
  Future<void> Function()? _quickInputCloser(bool closesQuickInput) =>
      closesQuickInput
      ? () async =>
            _effectEmitter.push(const CollectionQuickInputSentUiEffect())
      : null;

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
