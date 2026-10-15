import 'dart:typed_data';

import 'package:effect_emitter/effect_emitter.dart';
import 'package:fcis_core/fcis_core.dart';
import 'package:logging/logging.dart';
import 'package:result_dart/result_dart.dart';
import 'package:knit/core/attachments/domain/attachment_read_repository.dart';
import 'package:knit/core/attachments/domain/attachment_write_repository.dart';
import 'package:knit/core/attachments/domain/file_picker_port.dart';
import 'package:knit/core/attachments/domain/image_picker_port.dart';
import 'package:knit/core/attachments/domain/picked_audio.dart';
import 'package:knit/core/attachments/domain/picked_image.dart';
import 'package:knit/features/card_edit/domain/card_edit_failure.dart';
import 'package:knit/features/card_edit/domain/card_edit_links_read_repository.dart';
import 'package:knit/features/card_edit/domain/card_edit_links_write_repository.dart';
import 'package:knit/features/card_edit/domain/card_edit_targets_read_repository.dart';
import 'package:knit/features/card_edit/domain/card_edit_write_repository.dart';
import 'package:knit/features/card_edit/presentation/card_edit_action.dart';
import 'package:knit/features/card_edit/presentation/card_edit_effect.dart';
import 'package:knit/features/card_edit/presentation/card_edit_ui_effect.dart';
import 'package:knit/features/collection/domain/collection_models.dart';

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
    required FilePickerPort filePicker,
    required EffectEmitter<CardEditUiEffect> effectEmitter,
    required Logger logger,
  })  : _write = writeRepository,
        _linksRead = linksReadRepository,
        _linksWrite = linksWriteRepository,
        _targetsRead = targetsReadRepository,
        _attachmentRead = attachmentReadRepository,
        _attachmentWrite = attachmentWriteRepository,
        _picker = imagePicker,
        _filePicker = filePicker,
        _effectEmitter = effectEmitter,
        _log = logger;

  final CardEditWriteRepository _write;
  final CardEditLinksReadRepository _linksRead;
  final CardEditLinksWriteRepository _linksWrite;
  final CardEditTargetsReadRepository _targetsRead;
  final AttachmentReadRepository _attachmentRead;
  final AttachmentWriteRepository _attachmentWrite;
  final ImagePickerPort _picker;
  final FilePickerPort _filePicker;
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

      // --- attachment -----------------------------------------------------

      case LoadImageEffect(:final attachmentId):
        final result = await _attachmentRead.bytesOf(attachmentId);
        if (result.isFailure) {
          // Leave the card pointing at it; the section shows a broken-image
          // placeholder (the kind was already seeded as image).
          _log.warning('Card image bytes missing for $attachmentId');
          dispatch(const AttachmentEditEnded());
        } else {
          dispatch(AttachmentResolved(
            attachmentId: attachmentId,
            kind: CardKind.image,
            bytes: result.getOrThrow().bytes,
          ));
        }

      case PickImageEffect(:final cardId, :final previousAttachmentId):
        await _pickImageAndAttach(cardId, previousAttachmentId, dispatch);

      case PickFileEffect(:final cardId, :final previousAttachmentId):
        await _pickFileAndAttach(cardId, previousAttachmentId, dispatch);

      case RemoveAttachmentEffect(:final cardId, :final previousAttachmentId):
        final result = await _write.removeCardAttachment(cardId: cardId);
        if (result.isFailure) {
          final failure = result.error!;
          _log.severe('Remove card attachment failed', failure.error,
              failure.stackTrace);
          _effectEmitter.push(const CardEditShowMessageUiEffect(CardEditMessage.saveFailed));
          dispatch(const AttachmentEditEnded());
        } else {
          await _gcAttachment(previousAttachmentId);
          dispatch(const AttachmentResolved(attachmentId: null));
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

  /// Pick a photo → store it → point the card at the new image → GC the one it
  /// replaced. Any abort (cancelled pick, store/write failure) ends the busy
  /// state without changing the card.
  Future<void> _pickImageAndAttach(
    String cardId,
    String? previousAttachmentId,
    void Function(CardEditAction) dispatch,
  ) async {
    final picked = await _picker.pickImage();
    if (picked == null) {
      dispatch(const AttachmentEditEnded()); // cancelled
      return;
    }

    final created = await _attachmentWrite.createFromPicked(picked);
    if (created.isFailure) {
      _log.severe('Store picked image failed', created.error);
      _failAttachment(dispatch);
      return;
    }
    await _attach(
      cardId: cardId,
      attachmentId: created.getOrThrow(),
      kind: CardKind.image,
      bytes: picked.bytes,
      previousAttachmentId: previousAttachmentId,
      dispatch: dispatch,
    );
  }

  /// Pick any file → classify it by its mime (§4.2) → store it as the matching
  /// kind → point the card at it → GC the one it replaced.
  Future<void> _pickFileAndAttach(
    String cardId,
    String? previousAttachmentId,
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
      CardKind.image => _attachmentWrite
          .createFromPicked(PickedImage(bytes: file.bytes, mime: file.mime)),
      CardKind.audio => _attachmentWrite
          .createFromAudio(
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
      previousAttachmentId: previousAttachmentId,
      dispatch: dispatch,
    );
  }

  /// Point [cardId] at the freshly stored [attachmentId] of [kind], GC the one
  /// it replaced, and resolve the section with the rendered representation.
  Future<void> _attach({
    required String cardId,
    required String attachmentId,
    required CardKind kind,
    required String? previousAttachmentId,
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
          'Attach card attachment failed', failure.error, failure.stackTrace);
      _failAttachment(dispatch);
      return;
    }

    if (previousAttachmentId != null && previousAttachmentId != attachmentId) {
      await _gcAttachment(previousAttachmentId);
    }
    dispatch(AttachmentResolved(
      attachmentId: attachmentId,
      kind: kind,
      bytes: bytes,
      name: name,
      size: size,
    ));
  }

  /// Surface a write failure and clear the in-flight flag, leaving the card's
  /// current attachment untouched.
  void _failAttachment(void Function(CardEditAction) dispatch) {
    _effectEmitter
        .push(const CardEditShowMessageUiEffect(CardEditMessage.saveFailed));
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
