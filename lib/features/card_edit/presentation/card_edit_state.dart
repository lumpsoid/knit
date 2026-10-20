import 'package:flutter/foundation.dart';
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
    this.attachmentId,
    this.attachmentKind,
    this.attachmentName,
    this.attachmentSize,
    this.attachmentBusy = false,
    this.settled = false,
    this.settledBusy = false,
    this.emphasized = false,
    this.emphasizedBusy = false,
    this.isTimelinePreview = true,
  });

  final CardEditStatus status;
  final String cardId;
  final String initialText;

  /// The card's outgoing links (subtask 3). Reuses the §4.4 view-models.
  final List<ConnectionItem> links;
  final bool linksLoading;

  /// The card's current attachment id (§7.4.3); null when it has none.
  final String? attachmentId;

  /// The current attachment's kind (`image`/`audio`/`file`); drives which
  /// representation the section renders. Null when the card has no attachment.
  final CardKind? attachmentKind;

  /// For a file attachment, its original name and byte size (§7.4.8), shown on
  /// the file chip. Null for image/audio attachments.
  final String? attachmentName;
  final int? attachmentSize;

  /// An attachment add/replace/remove is in flight — gates the controls.
  final bool attachmentBusy;

  /// Whether the card is settled (§3.3); the toggle applies at once, like the
  /// links and the attachment.
  final bool settled;

  /// A settle write is in flight — gates the toggle.
  final bool settledBusy;

  /// Whether the card is emphasized (§3.3). Settled and emphasized are
  /// exclusive: setting one clears the other.
  final bool emphasized;

  /// An emphasis write is in flight — gates the toggle.
  final bool emphasizedBusy;

  /// A settle or emphasis write is in flight; both toggles wait for it, as
  /// each write can clear the other mark.
  bool get markBusy => settledBusy || emphasizedBusy;

  /// The card is its collection's home-timeline preview (§8.6.3), so a text or
  /// attachment edit must refresh the Timeline. True until the read says
  /// otherwise: an extra refresh is harmless, a missed one leaves a stale row.
  final bool isTimelinePreview;

  bool get hasAttachment => attachmentId != null;

  static const Object _unset = Object();

  CardEditState copyWith({
    CardEditStatus? status,
    String? cardId,
    String? initialText,
    List<ConnectionItem>? links,
    bool? linksLoading,
    Object? attachmentId = _unset,
    Object? attachmentKind = _unset,
    Object? attachmentName = _unset,
    Object? attachmentSize = _unset,
    bool? attachmentBusy,
    bool? settled,
    bool? settledBusy,
    bool? emphasized,
    bool? emphasizedBusy,
    bool? isTimelinePreview,
  }) => CardEditState(
    status: status ?? this.status,
    cardId: cardId ?? this.cardId,
    initialText: initialText ?? this.initialText,
    links: links ?? this.links,
    linksLoading: linksLoading ?? this.linksLoading,
    attachmentId: attachmentId == _unset
        ? this.attachmentId
        : attachmentId as String?,
    attachmentKind: attachmentKind == _unset
        ? this.attachmentKind
        : attachmentKind as CardKind?,
    attachmentName: attachmentName == _unset
        ? this.attachmentName
        : attachmentName as String?,
    attachmentSize: attachmentSize == _unset
        ? this.attachmentSize
        : attachmentSize as int?,
    attachmentBusy: attachmentBusy ?? this.attachmentBusy,
    settled: settled ?? this.settled,
    settledBusy: settledBusy ?? this.settledBusy,
    emphasized: emphasized ?? this.emphasized,
    emphasizedBusy: emphasizedBusy ?? this.emphasizedBusy,
    isTimelinePreview: isTimelinePreview ?? this.isTimelinePreview,
  );
}
