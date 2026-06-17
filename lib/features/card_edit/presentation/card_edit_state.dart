import 'package:flutter/foundation.dart';
import 'package:knit/features/card_edit/domain/card_edit_models.dart';
import 'package:knit/features/collection/domain/collection_models.dart';
import 'package:knit/features/connections/domain/connections_models.dart';

enum CardEditStatus { editing, saving, failed }

/// State for the Card Edit page (§4.3). The text being edited lives in a
/// page-owned [TextEditingController] (seeded once from [initialText]), so a
/// links/attachment reload never disturbs unsaved text. [status] gates the Save
/// control. The links + attachment sections are managed in place (each change is
/// its own signed write, applied immediately) and reflected here.
@immutable
class CardEditState {
  const CardEditState({
    this.status = CardEditStatus.editing,
    this.cardId = '',
    this.initialText = '',
    this.links = const [],
    this.linksLoading = false,
    this.targets = const [],
    this.attachmentId,
    this.attachmentKind,
    this.imageBytes,
    this.attachmentName,
    this.attachmentSize,
    this.attachmentBusy = false,
  });

  final CardEditStatus status;
  final String cardId;
  final String initialText;

  /// The card's outgoing links (subtask 3). Reuses the §4.4 view-models.
  final List<ConnectionItem> links;
  final bool linksLoading;

  /// The link-picker target tree (every collection + its cards), loaded up front.
  final List<CardLinkCollectionTargets> targets;

  /// The card's current attachment id (§7.4.3); null when it has none.
  final String? attachmentId;

  /// The current attachment's kind (`image`/`audio`/`file`); drives which
  /// representation the section renders. Null when the card has no attachment.
  final CardKind? attachmentKind;

  /// Decoded bytes of an *image* attachment, for [AttachmentImage]; null for
  /// audio/file attachments (they render as chips) and while loading/absent.
  final Uint8List? imageBytes;

  /// For a file attachment, its original name and byte size (§7.4.8), shown on
  /// the file chip. Null for image/audio attachments.
  final String? attachmentName;
  final int? attachmentSize;

  /// An attachment add/replace/remove is in flight — gates the controls.
  final bool attachmentBusy;

  bool get hasAttachment => attachmentId != null;

  static const Object _unset = Object();

  CardEditState copyWith({
    CardEditStatus? status,
    String? cardId,
    String? initialText,
    List<ConnectionItem>? links,
    bool? linksLoading,
    List<CardLinkCollectionTargets>? targets,
    Object? attachmentId = _unset,
    Object? attachmentKind = _unset,
    Object? imageBytes = _unset,
    Object? attachmentName = _unset,
    Object? attachmentSize = _unset,
    bool? attachmentBusy,
  }) =>
      CardEditState(
        status: status ?? this.status,
        cardId: cardId ?? this.cardId,
        initialText: initialText ?? this.initialText,
        links: links ?? this.links,
        linksLoading: linksLoading ?? this.linksLoading,
        targets: targets ?? this.targets,
        attachmentId:
            attachmentId == _unset ? this.attachmentId : attachmentId as String?,
        attachmentKind: attachmentKind == _unset
            ? this.attachmentKind
            : attachmentKind as CardKind?,
        imageBytes:
            imageBytes == _unset ? this.imageBytes : imageBytes as Uint8List?,
        attachmentName: attachmentName == _unset
            ? this.attachmentName
            : attachmentName as String?,
        attachmentSize: attachmentSize == _unset
            ? this.attachmentSize
            : attachmentSize as int?,
        attachmentBusy: attachmentBusy ?? this.attachmentBusy,
      );
}
