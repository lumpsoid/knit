import 'package:effect_emitter/effect_emitter.dart';
import 'package:fcis_core/fcis_core.dart';
import 'package:logging/logging.dart';
import 'package:result_dart/result_dart.dart';
import 'package:knit/core/attachments/domain/attachment_read_repository.dart';
import 'package:knit/core/attachments/domain/attachment_write_repository.dart';
import 'package:knit/core/attachments/domain/image_picker_port.dart';
import 'package:knit/features/card_edit/domain/card_edit_failure.dart';
import 'package:knit/features/card_edit/domain/card_edit_links_read_repository.dart';
import 'package:knit/features/card_edit/domain/card_edit_links_write_repository.dart';
import 'package:knit/features/card_edit/domain/card_edit_targets_read_repository.dart';
import 'package:knit/features/card_edit/domain/card_edit_write_repository.dart';
import 'package:knit/features/card_edit/presentation/card_edit_action.dart';
import 'package:knit/features/card_edit/presentation/card_edit_effect.dart';
import 'package:knit/features/card_edit/presentation/card_edit_ui_effect.dart';

/// Imperative shell for the Card Edit page (fcis.md §6.6). Unwraps each
/// repository [Result] at the seam (result.md §9.3): the updater never sees a
/// Result. Text saves pop the page; link and image edits resync only the
/// affected section (the page-owned text field is untouched). A failed write
/// surfaces a message and clears the in-flight flag.
class CardEditShell extends Shell<CardEditEffect, CardEditAction> {
  CardEditShell({
    required CardEditWriteRepository writeRepository,
    required CardEditLinksReadRepository linksReadRepository,
    required CardEditLinksWriteRepository linksWriteRepository,
    required CardEditTargetsReadRepository targetsReadRepository,
    required AttachmentReadRepository attachmentReadRepository,
    required AttachmentWriteRepository attachmentWriteRepository,
    required ImagePickerPort imagePicker,
    required EffectEmitter<CardEditUiEffect> effectEmitter,
    required Logger logger,
  })  : _write = writeRepository,
        _linksRead = linksReadRepository,
        _linksWrite = linksWriteRepository,
        _targetsRead = targetsReadRepository,
        _attachmentRead = attachmentReadRepository,
        _attachmentWrite = attachmentWriteRepository,
        _picker = imagePicker,
        _effectEmitter = effectEmitter,
        _log = logger;

  final CardEditWriteRepository _write;
  final CardEditLinksReadRepository _linksRead;
  final CardEditLinksWriteRepository _linksWrite;
  final CardEditTargetsReadRepository _targetsRead;
  final AttachmentReadRepository _attachmentRead;
  final AttachmentWriteRepository _attachmentWrite;
  final ImagePickerPort _picker;
  final EffectEmitter<CardEditUiEffect> _effectEmitter;
  final Logger _log;

  @override
  Future<void> run(
    CardEditEffect effect, {
    required void Function(CardEditAction) dispatch,
  }) async {
    switch (effect) {
      case SaveCardEffect(:final cardId, :final text):
        final result = await _write.editCard(cardId: cardId, text: text);
        result.onTap(
          (_) {
            dispatch(const SaveSucceeded());
            _effectEmitter.push(const CardEditSavedUiEffect());
          },
          (failure) {
            _log.severe('Card edit failed', failure.error, failure.stackTrace);
            _effectEmitter.push(const CardEditShowMessageUiEffect(CardEditMessage.saveFailed));
            dispatch(const SaveFailed());
          },
        );

      // --- links ----------------------------------------------------------

      case LoadLinksEffect(:final cardId):
        final result = await _linksRead.linksOf(cardId);
        result.onTap(
          (links) => dispatch(LinksLoaded(links)),
          (failure) {
            _log.severe(
                'Card links load failed', failure.error, failure.stackTrace);
            dispatch(const LinksLoadFailed());
          },
        );

      case LoadTargetsEffect(:final cardId):
        final result = await _targetsRead.loadTargets(excludeCardId: cardId);
        result.onTap(
          (targets) => dispatch(TargetsLoaded(targets)),
          (failure) => _log.severe('Card link targets load failed',
              failure.error, failure.stackTrace),
        );

      case AddLinkEffect(:final cardId, :final targetKind, :final targetId):
        final result = await _linksWrite.addLink(
          sourceCardId: cardId,
          targetKind: targetKind,
          targetId: targetId,
        );
        _afterLinkWrite(result, 'add link', dispatch);

      case RemoveLinkEffect(:final linkId):
        final result = await _linksWrite.removeLink(linkId);
        _afterLinkWrite(result, 'remove link', dispatch);

      // --- image ----------------------------------------------------------

      case LoadImageEffect(:final attachmentId):
        final result = await _attachmentRead.bytesOf(attachmentId);
        if (result.isFailure) {
          _log.warning('Card image bytes missing for $attachmentId');
          dispatch(const ImageBytesLoaded(null));
        } else {
          dispatch(ImageBytesLoaded(result.getOrThrow().bytes));
        }

      case PickImageEffect(:final cardId, :final previousAttachmentId):
        await _pickAndAttach(cardId, previousAttachmentId, dispatch);

      case RemoveImageEffect(:final cardId, :final previousAttachmentId):
        final result = await _write.removeCardImage(cardId: cardId);
        if (result.isFailure) {
          final failure = result.error!;
          _log.severe('Remove card image failed', failure.error,
              failure.stackTrace);
          _effectEmitter.push(const CardEditShowMessageUiEffect(CardEditMessage.saveFailed));
          dispatch(const ImageEditEnded());
        } else {
          await _gcAttachment(previousAttachmentId);
          dispatch(const ImageChanged(null));
        }
    }
  }

  /// Resync the link list whether the write succeeded or failed (a failure also
  /// surfaces a message); the reload clears the in-flight spinner either way.
  void _afterLinkWrite(
    Result<String, CardEditFailure> result,
    String label,
    void Function(CardEditAction) dispatch,
  ) {
    result.onTap(
      (_) => dispatch(const LinksChanged()),
      (failure) {
        _log.severe('Card $label failed', failure.error, failure.stackTrace);
        _effectEmitter.push(const CardEditShowMessageUiEffect(CardEditMessage.saveFailed));
        dispatch(const LinksChanged());
      },
    );
  }

  /// Pick → store → point the card at the new image → GC the one it replaced.
  /// Any abort (cancelled pick, store/write failure) ends the busy state without
  /// changing the card.
  Future<void> _pickAndAttach(
    String cardId,
    String? previousAttachmentId,
    void Function(CardEditAction) dispatch,
  ) async {
    final picked = await _picker.pickImage();
    if (picked == null) {
      dispatch(const ImageEditEnded()); // cancelled
      return;
    }

    final created = await _attachmentWrite.createFromPicked(picked);
    if (created.isFailure) {
      _log.severe('Store picked image failed', created.error);
      _effectEmitter.push(const CardEditShowMessageUiEffect(CardEditMessage.saveFailed));
      dispatch(const ImageEditEnded());
      return;
    }
    final newId = created.getOrThrow();

    final attached = await _write.setCardImage(cardId: cardId, attachmentId: newId);
    if (attached.isFailure) {
      final failure = attached.error!;
      _log.severe('Attach card image failed', failure.error, failure.stackTrace);
      _effectEmitter.push(const CardEditShowMessageUiEffect(CardEditMessage.saveFailed));
      dispatch(const ImageEditEnded());
      return;
    }

    if (previousAttachmentId != null && previousAttachmentId != newId) {
      await _gcAttachment(previousAttachmentId);
    }
    dispatch(ImageChanged(newId));
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
