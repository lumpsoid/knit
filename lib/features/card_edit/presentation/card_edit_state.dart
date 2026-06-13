import 'package:flutter/foundation.dart';
import 'package:knit/features/card_edit/domain/card_edit_models.dart';
import 'package:knit/features/connections/domain/connections_models.dart';

enum CardEditStatus { editing, saving, failed }

/// State for the Card Edit page (§4.3). The text being edited lives in a
/// page-owned [TextEditingController] (seeded once from [initialText]), so a
/// links/image reload never disturbs unsaved text. [status] gates the Save
/// control. The links + image sections are managed in place (each change is its
/// own signed write, applied immediately) and reflected here.
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
    this.imageBytes,
    this.imageBusy = false,
  });

  final CardEditStatus status;
  final String cardId;
  final String initialText;

  /// The card's outgoing links (subtask 3). Reuses the §4.4 view-models.
  final List<ConnectionItem> links;
  final bool linksLoading;

  /// The link-picker target tree (every collection + its cards), loaded up front.
  final List<CardLinkCollectionTargets> targets;

  /// The card's current image attachment id (subtask 4); null when it has none.
  final String? attachmentId;

  /// Decoded bytes of [attachmentId], for [AttachmentImage]; null while loading
  /// or absent.
  final Uint8List? imageBytes;

  /// An image add/replace/remove is in flight — gates the image controls.
  final bool imageBusy;

  bool get hasImage => attachmentId != null;

  static const Object _unset = Object();

  CardEditState copyWith({
    CardEditStatus? status,
    String? cardId,
    String? initialText,
    List<ConnectionItem>? links,
    bool? linksLoading,
    List<CardLinkCollectionTargets>? targets,
    Object? attachmentId = _unset,
    Object? imageBytes = _unset,
    bool? imageBusy,
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
        imageBytes:
            imageBytes == _unset ? this.imageBytes : imageBytes as Uint8List?,
        imageBusy: imageBusy ?? this.imageBusy,
      );
}
