/// Route-args carrier for the Card Edit page (cross_feature.md §2). The origin
/// screen (the Collection page) writes the card to edit *before* navigating; the
/// Card Edit page reads it on entry and dispatches [ViewAttached]. Navigation
/// itself carries no payload — the carrier is the payload — so neither feature
/// couples to the navigation system for its input.
library;

import 'package:knit/features/collection/domain/collection_models.dart';

/// Read side — what the Card Edit page consumes on entry.
abstract interface class CardEditRouteArgs {
  /// The card to edit. Empty before any origin has written one.
  String get cardId;

  /// The card's current body text, used to seed the editor field.
  String get initialText;

  /// The card's current attachment id (§7.4.3), or null if it has none. Seeds
  /// the attachment section without a second read.
  String? get initialAttachmentId;

  /// The current attachment's [CardKind] (`image`/`audio`/`file`), so the page
  /// renders the right representation without re-deriving it; null when the card
  /// has no attachment.
  CardKind? get initialAttachmentKind;

  /// For a file attachment, its original file name and byte size (§7.4.8), so
  /// the file chip can label/size it without loading the bytes; null otherwise.
  String? get initialFileName;
  int? get initialFileSize;
}

/// Write side — what an origin screen (Collection) sets before navigating.
abstract interface class CardEditRouteArgsWriter {
  void open({
    required String cardId,
    required String initialText,
    String? initialAttachmentId,
    CardKind? initialAttachmentKind,
    String? initialFileName,
    int? initialFileSize,
  });
}

/// The store implements both halves.
abstract interface class CardEditRouteArgsStore
    implements CardEditRouteArgs, CardEditRouteArgsWriter {}

/// Plain in-memory carrier — a single most-recent target. The destination reads
/// it synchronously on entry, so no persistence is needed.
class InMemoryCardEditRouteArgsStore implements CardEditRouteArgsStore {
  String _cardId = '';
  String _initialText = '';
  String? _initialAttachmentId;
  CardKind? _initialAttachmentKind;
  String? _initialFileName;
  int? _initialFileSize;

  @override
  String get cardId => _cardId;

  @override
  String get initialText => _initialText;

  @override
  String? get initialAttachmentId => _initialAttachmentId;

  @override
  CardKind? get initialAttachmentKind => _initialAttachmentKind;

  @override
  String? get initialFileName => _initialFileName;

  @override
  int? get initialFileSize => _initialFileSize;

  @override
  void open({
    required String cardId,
    required String initialText,
    String? initialAttachmentId,
    CardKind? initialAttachmentKind,
    String? initialFileName,
    int? initialFileSize,
  }) {
    _cardId = cardId;
    _initialText = initialText;
    _initialAttachmentId = initialAttachmentId;
    _initialAttachmentKind = initialAttachmentKind;
    _initialFileName = initialFileName;
    _initialFileSize = initialFileSize;
  }
}
