import 'dart:typed_data';

import 'package:effect_emitter/effect_emitter.dart';
import 'package:fcis_core/fcis_core.dart';
import 'package:logging/logging.dart';
import 'package:result_dart/result_dart.dart';
import 'package:knit/core/attachments/domain/attachment_read_repository.dart';
import 'package:knit/core/attachments/domain/attachment_write_repository.dart';
import 'package:knit/core/attachments/domain/file_picker_port.dart';
import 'package:knit/core/attachments/domain/image_optimizer_port.dart';
import 'package:knit/core/attachments/domain/image_picker_port.dart';
import 'package:knit/core/attachments/presentation/attachment_image_cache.dart';
import 'package:knit/core/attachments/domain/picked_audio.dart';
import 'package:knit/core/attachments/domain/picked_image.dart';
import 'package:knit/features/card_edit/domain/card_edit_links_read_repository.dart';
import 'package:knit/features/card_edit/domain/card_edit_timeline_preview_read_repository.dart';
import 'package:knit/features/card_edit/domain/card_edit_write_repository.dart';
import 'package:knit/features/card_edit/presentation/card_edit_action.dart';
import 'package:knit/features/card_edit/presentation/card_edit_effect.dart';
import 'package:knit/features/card_edit/presentation/card_edit_ui_effect.dart';
import 'package:knit/features/card_links/domain/card_links_failure.dart';
import 'package:knit/features/card_links/presentation/card_links_controller.dart';
import 'package:knit/features/collection/domain/collection_models.dart';
import 'package:knit/features/timeline/domain/timeline_channel.dart';

/// Imperative shell for the Card Edit page (fcis.md §6.6). Unwraps each
/// repository [Result] at the seam (result.md §9.3): the updater never sees a
/// Result. Text saves pop the page; link and image edits resync only the
/// affected section (the page-owned text field is untouched). A failed write
/// surfaces a message and clears the in-flight flag.
class CardEditShell extends Shell<CardEditEffect, CardEditAction> {
  CardEditShell({
    required CardEditWriteRepository writeRepository,
    required CardEditLinksReadRepository linksReadRepository,
    required CardEditTimelinePreviewReadRepository timelinePreviewRepository,
    required TimelineChannelEmitter timelineChannel,
    required CardLinksController cardLinks,
    required AttachmentImageCache imageCache,
    required AttachmentReadRepository attachmentReadRepository,
    required AttachmentWriteRepository attachmentWriteRepository,
    required ImagePickerPort imagePicker,
    required ImageOptimizerPort imageOptimizer,
    required FilePickerPort filePicker,
    required EffectEmitter<CardEditUiEffect> effectEmitter,
    required Logger logger,
  }) : _write = writeRepository,
       _linksRead = linksReadRepository,
       _timelinePreview = timelinePreviewRepository,
       _timelineChannel = timelineChannel,
       _cardLinks = cardLinks,
       _images = imageCache,
       _attachmentRead = attachmentReadRepository,
       _attachmentWrite = attachmentWriteRepository,
       _picker = imagePicker,
       _optimizer = imageOptimizer,
       _filePicker = filePicker,
       _effectEmitter = effectEmitter,
       _log = logger;

  final CardEditWriteRepository _write;
  final CardEditLinksReadRepository _linksRead;
  final CardEditTimelinePreviewReadRepository _timelinePreview;
  final TimelineChannelEmitter _timelineChannel;
  final CardLinksController _cardLinks;
  final AttachmentImageCache _images;
  final AttachmentReadRepository _attachmentRead;
  final AttachmentWriteRepository _attachmentWrite;
  final ImagePickerPort _picker;
  final ImageOptimizerPort _optimizer;
  final FilePickerPort _filePicker;
  final EffectEmitter<CardEditUiEffect> _effectEmitter;
  final Logger _log;

  @override
  Future<void> run(
    CardEditEffect effect, {
    required void Function(CardEditAction) dispatch,
  }) async {
    switch (effect) {
      case SaveCardEffect(:final cardId, :final text, :final kind):
        final result = await _write.editCard(
          cardId: cardId,
          text: text,
          kind: kind,
        );
        result.onTap(
          (_) {
            dispatch(const SaveSucceeded());
            _effectEmitter.push(const CardEditSavedUiEffect());
          },
          (failure) {
            _log.severe('Card edit failed', failure.error, failure.stackTrace);
            _effectEmitter.push(
              const CardEditShowMessageUiEffect(CardEditMessage.saveFailed),
            );
            dispatch(const SaveFailed());
          },
        );

      case SetSettledEffect(:final cardId, :final settled):
        final result = await _write.setCardSettled(
          cardId: cardId,
          settled: settled,
        );
        result.onTap((_) => dispatch(SettledResolved(settled)), (failure) {
          _log.severe('Card settle failed', failure.error, failure.stackTrace);
          _effectEmitter.push(
            const CardEditShowMessageUiEffect(CardEditMessage.saveFailed),
          );
          dispatch(const SettledEditFailed());
        });

      case SetEmphasizedEffect(:final cardId, :final emphasized):
        final result = await _write.setCardEmphasized(
          cardId: cardId,
          emphasized: emphasized,
        );
        result.onTap((_) => dispatch(EmphasizedResolved(emphasized)), (
          failure,
        ) {
          _log.severe(
            'Card emphasis failed',
            failure.error,
            failure.stackTrace,
          );
          _effectEmitter.push(
            const CardEditShowMessageUiEffect(CardEditMessage.saveFailed),
          );
          dispatch(const EmphasizedEditFailed());
        });

      // --- timeline -------------------------------------------------------

      case LoadTimelinePreviewEffect(:final cardId, :final collectionId):
        final result = await _timelinePreview.isTimelinePreview(
          cardId: cardId,
          collectionId: collectionId,
        );
        // On failure the state keeps its default (refresh after an edit).
        result.onTap(
          (isPreview) => dispatch(TimelinePreviewResolved(isPreview)),
          (failure) {
            _log.warning(
              'Timeline preview check failed',
              failure.error,
              failure.stackTrace,
            );
          },
        );

      case RefreshTimelineEffect():
        // The Timeline is mounted underneath; nudge it to re-read via its input
        // channel (cross_feature.md §3).
        _timelineChannel.emit(const RefreshChannelEvent());

      // --- links ----------------------------------------------------------

      case LoadLinksEffect(:final cardId):
        final result = await _linksRead.linksOf(cardId);
        result.onTap((links) => dispatch(LinksLoaded(links)), (failure) {
          _log.severe(
            'Card links load failed',
            failure.error,
            failure.stackTrace,
          );
          dispatch(const LinksLoadFailed());
        });

      case AddLinkEffect(:final cardId, :final targetKind, :final targetId):
        final result = await _cardLinks.link(
          sourceId: cardId,
          targetKind: targetKind,
          targetId: targetId,
        );
        _afterLinkWrite(result, 'add link', dispatch);

      case AddLinkToNewCollectionEffect(:final cardId, :final title):
        final result = await _cardLinks.linkToNewCollection(
          sourceIds: [cardId],
          title: title,
        );
        // Home lists the new collection.
        if (result.isSuccess) {
          _timelineChannel.emit(const RefreshChannelEvent());
        }
        _afterLinkWrite(result, 'add link to a new collection', dispatch);

      case RemoveLinkEffect(:final linkId):
        final result = await _cardLinks.unlink(linkId);
        _afterLinkWrite(result, 'remove link', dispatch);

      // --- attachment -----------------------------------------------------

      case ShowImageEffect(:final attachmentIds):
        await _images.show(this, attachmentIds);

      case ReleaseImageEffect():
        _images.release(this);

      case PickImageEffect(
        :final cardId,
        :final keptImageIds,
        :final replacedAttachmentId,
      ):
        await _pickImagesAndAttach(
          cardId,
          keptImageIds,
          replacedAttachmentId,
          dispatch,
        );

      case RemoveImageEffect(
        :final cardId,
        :final remainingIds,
        :final removedId,
      ):
        final result = remainingIds.isEmpty
            ? await _write.removeCardAttachment(cardId: cardId)
            : await _write.setCardImages(
                cardId: cardId,
                attachmentIds: remainingIds,
              );
        if (result.isFailure) {
          final failure = result.error!;
          _log.severe(
            'Remove card image failed',
            failure.error,
            failure.stackTrace,
          );
          _failAttachment(dispatch);
          return;
        }
        await _gcAttachment(removedId);
        dispatch(
          AttachmentResolved(
            attachmentId: remainingIds.firstOrNull,
            moreAttachmentIds: remainingIds.skip(1).toList(),
            kind: remainingIds.isEmpty ? null : CardKind.image,
          ),
        );

      case PickFileEffect(:final cardId, :final previousAttachmentIds):
        await _pickFileAndAttach(cardId, previousAttachmentIds, dispatch);

      case OptimizeImageEffect(:final cardId, :final attachmentIds):
        await _optimizeImages(cardId, attachmentIds, dispatch);

      case RemoveAttachmentEffect(:final cardId, :final previousAttachmentIds):
        final result = await _write.removeCardAttachment(cardId: cardId);
        if (result.isFailure) {
          final failure = result.error!;
          _log.severe(
            'Remove card attachment failed',
            failure.error,
            failure.stackTrace,
          );
          _effectEmitter.push(
            const CardEditShowMessageUiEffect(CardEditMessage.saveFailed),
          );
          dispatch(const AttachmentEditEnded());
        } else {
          for (final id in previousAttachmentIds) {
            await _gcAttachment(id);
          }
          dispatch(const AttachmentResolved(attachmentId: null));
        }
    }
  }

  /// Resync the link list whether the write succeeded or failed (a failure also
  /// surfaces a message); the reload clears the in-flight spinner either way.
  void _afterLinkWrite(
    Result<Object, CardLinksFailure> result,
    String label,
    void Function(CardEditAction) dispatch,
  ) {
    result.onTap((_) => dispatch(const LinksChanged()), (failure) {
      _log.severe('Card $label failed', failure.error, failure.stackTrace);
      _effectEmitter.push(
        const CardEditShowMessageUiEffect(CardEditMessage.saveFailed),
      );
      dispatch(const LinksChanged());
    });
  }

  /// Pick photos → store each → make the card an image card holding
  /// [keptImageIds] then them → GC the attachment they replaced. Any abort
  /// (cancelled pick, store/write failure) ends the busy state without
  /// changing the card; photos already stored for it are dropped again.
  Future<void> _pickImagesAndAttach(
    String cardId,
    List<String> keptImageIds,
    String? replacedAttachmentId,
    void Function(CardEditAction) dispatch,
  ) async {
    final picked = await _picker.pickImages();
    if (picked.isEmpty) {
      dispatch(const AttachmentEditEnded()); // cancelled
      return;
    }

    final added = <String>[];
    for (final image in picked) {
      final created = await _attachmentWrite.createFromPicked(image);
      if (created.isFailure) {
        _log.severe('Store picked image failed', created.error);
        for (final id in added) {
          await _gcAttachment(id);
        }
        _failAttachment(dispatch);
        return;
      }
      added.add(created.getOrThrow());
      // The bytes are in hand: seed the shared cache so no page re-reads them.
      _images.put(added.last, image.bytes);
    }
    final images = [...keptImageIds, ...added];
    final attached = await _write.setCardImages(
      cardId: cardId,
      attachmentIds: images,
    );
    if (attached.isFailure) {
      final failure = attached.error!;
      _log.severe('Add card images failed', failure.error, failure.stackTrace);
      for (final id in added) {
        await _gcAttachment(id);
      }
      _failAttachment(dispatch);
      return;
    }
    await _gcAttachment(replacedAttachmentId);
    dispatch(
      AttachmentResolved(
        attachmentId: images.first,
        moreAttachmentIds: images.sublist(1),
        kind: CardKind.image,
      ),
    );
  }

  /// Read each of the card's images → shrink it → store the copy; then point
  /// the card at the copies (same order) and GC the originals they replace.
  /// An image with nothing to gain stays; when none gets smaller, say so and
  /// leave the card as it is.
  Future<void> _optimizeImages(
    String cardId,
    List<String> attachmentIds,
    void Function(CardEditAction) dispatch,
  ) async {
    final images = <String>[];
    final replaced = <String>[];
    var fromBytes = 0;
    var toBytes = 0;
    for (final attachmentId in attachmentIds) {
      final read = await _attachmentRead.bytesOf(attachmentId);
      if (read.isFailure) {
        _log.severe('Read image to optimize failed', read.error);
        for (final id in images) {
          if (!attachmentIds.contains(id)) await _gcAttachment(id);
        }
        _failAttachment(dispatch);
        return;
      }
      final original = read.getOrThrow();
      PickedImage? optimized;
      try {
        optimized = await _optimizer.optimize(
          PickedImage(bytes: original.bytes, mime: original.mime),
        );
      } catch (e, s) {
        _log.severe('Optimize image failed', e, s);
        optimized = null;
      }
      final created = optimized == null
          ? null
          : await _attachmentWrite.createFromPicked(optimized);
      if (optimized == null || created == null || created.isFailure) {
        if (created != null) {
          _log.severe('Store optimized image failed', created.error);
        }
        images.add(attachmentId);
        continue;
      }
      final copyId = created.getOrThrow();
      _images.put(copyId, optimized.bytes);
      images.add(copyId);
      replaced.add(attachmentId);
      fromBytes += original.bytes.length;
      toBytes += optimized.bytes.length;
    }

    if (replaced.isEmpty) {
      _effectEmitter.push(
        const CardEditShowMessageUiEffect(CardEditMessage.imageNotSmaller),
      );
      dispatch(const AttachmentEditEnded());
      return;
    }
    final attached = await _write.setCardImages(
      cardId: cardId,
      attachmentIds: images,
    );
    if (attached.isFailure) {
      final failure = attached.error!;
      _log.severe(
        'Attach optimized images failed',
        failure.error,
        failure.stackTrace,
      );
      for (final id in images) {
        if (!attachmentIds.contains(id)) await _gcAttachment(id);
      }
      _failAttachment(dispatch);
      return;
    }
    for (final id in replaced) {
      await _gcAttachment(id);
    }
    dispatch(
      AttachmentResolved(
        attachmentId: images.first,
        moreAttachmentIds: images.sublist(1),
        kind: CardKind.image,
      ),
    );
    _effectEmitter.push(
      CardEditImageOptimizedUiEffect(fromBytes: fromBytes, toBytes: toBytes),
    );
  }

  /// Pick any file → classify it by its mime (§4.2) → store it as the matching
  /// kind → point the card at it → GC the ones it replaced.
  Future<void> _pickFileAndAttach(
    String cardId,
    List<String> previousAttachmentIds,
    void Function(CardEditAction) dispatch,
  ) async {
    final file = await _filePicker.pickFile();
    if (file == null) {
      dispatch(const AttachmentEditEnded()); // cancelled
      return;
    }

    // The mime→kind decision lives in the domain (collection_models); the shell
    // only routes the matching store call and labels the result.
    final kind = CardKind.forFileMime(file.mime);
    final created = await switch (kind) {
      CardKind.image => _attachmentWrite.createFromPicked(
        PickedImage(bytes: file.bytes, mime: file.mime),
      ),
      CardKind.audio => _attachmentWrite.createFromAudio(
        PickedAudio(bytes: file.bytes, mime: file.mime, name: file.name),
      ),
      _ => _attachmentWrite.createFromFile(file),
    };
    if (created.isFailure) {
      _log.severe('Store picked file failed', created.error);
      _failAttachment(dispatch);
      return;
    }
    await _attach(
      cardId: cardId,
      attachmentId: created.getOrThrow(),
      kind: kind,
      bytes: kind == CardKind.image ? file.bytes : null,
      name: kind == CardKind.file ? file.name : null,
      size: file.bytes.length,
      previousAttachmentIds: previousAttachmentIds,
      dispatch: dispatch,
    );
  }

  /// Point [cardId] at the freshly stored [attachmentId] of [kind], GC the
  /// ones it replaced, and resolve the section with the rendered
  /// representation.
  Future<void> _attach({
    required String cardId,
    required String attachmentId,
    required CardKind kind,
    required List<String> previousAttachmentIds,
    required void Function(CardEditAction) dispatch,
    Uint8List? bytes,
    String? name,
    int? size,
  }) async {
    final attached = await _write.setCardAttachment(
      cardId: cardId,
      attachmentId: attachmentId,
      kind: kind,
    );
    if (attached.isFailure) {
      final failure = attached.error!;
      _log.severe(
        'Attach card attachment failed',
        failure.error,
        failure.stackTrace,
      );
      _failAttachment(dispatch);
      return;
    }

    for (final previous in previousAttachmentIds) {
      if (previous != attachmentId) await _gcAttachment(previous);
    }
    // An image's bytes are in hand: seed the shared cache so no page re-reads
    // them.
    if (bytes != null) _images.put(attachmentId, bytes);
    dispatch(
      AttachmentResolved(
        attachmentId: attachmentId,
        kind: kind,
        name: name,
        size: size,
      ),
    );
  }

  /// Surface a write failure and clear the in-flight flag, leaving the card's
  /// current attachment untouched.
  void _failAttachment(void Function(CardEditAction) dispatch) {
    _effectEmitter.push(
      const CardEditShowMessageUiEffect(CardEditMessage.saveFailed),
    );
    dispatch(const AttachmentEditEnded());
  }

  /// Drop the replaced/removed attachment record (ref-counted blob GC happens
  /// inside the repo). A GC failure is non-fatal — the card already points away.
  Future<void> _gcAttachment(String? attachmentId) async {
    if (attachmentId == null) return;
    final result = await _attachmentWrite.delete(attachmentId);
    if (result.isFailure) {
      _log.warning('Attachment GC failed for $attachmentId: ${result.error}');
    }
  }
}
