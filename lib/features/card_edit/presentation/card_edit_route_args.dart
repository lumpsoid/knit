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

  /// The card's collection — the link picker never offers it as a target.
  String get collectionId;

  /// The card's current body text, used to seed the editor field.
  String get initialText;

  /// The card's [CardKind]: a Connection card may save a blank label.
  CardKind get initialKind;

  /// The card's current attachment id (§7.4.3), or null if it has none. Seeds
  /// the attachment section without a second read.
  String? get initialAttachmentId;

  /// An image card's further images after [initialAttachmentId], in order
  /// (§4.2); empty otherwise.
  List<String> get initialMoreAttachmentIds;

  /// The current attachment's [CardKind] (`image`/`audio`/`file`), so the page
  /// renders the right representation without re-deriving it; null when the card
  /// has no attachment.
  CardKind? get initialAttachmentKind;

  /// For a file attachment, its original file name and byte size (§7.4.8), so
  /// the file chip can label/size it without loading the bytes; null otherwise.
  String? get initialFileName;
  int? get initialFileSize;

  /// Whether the card is settled (§3.3), seeding the Settled toggle.
  bool get initialSettled;

  /// Whether the card is emphasized (§3.3), seeding the Emphasized toggle.
  bool get initialEmphasized;
}

/// Write side — what an origin screen (Collection) sets before navigating.
abstract interface class CardEditRouteArgsWriter {
  void open({
    required String cardId,
    required String collectionId,
    required String initialText,
    CardKind initialKind,
    String? initialAttachmentId,
    List<String> initialMoreAttachmentIds,
    CardKind? initialAttachmentKind,
    String? initialFileName,
    int? initialFileSize,
    bool initialSettled,
    bool initialEmphasized,
  });
}

/// The store implements both halves.
abstract interface class CardEditRouteArgsStore
    implements CardEditRouteArgs, CardEditRouteArgsWriter {}

/// Plain in-memory carrier — a single most-recent target. The destination reads
/// it synchronously on entry, so no persistence is needed.
class InMemoryCardEditRouteArgsStore implements CardEditRouteArgsStore {
  String _cardId = '';
  String _collectionId = '';
  String _initialText = '';
  CardKind _initialKind = CardKind.text;
  String? _initialAttachmentId;
  List<String> _initialMoreAttachmentIds = const [];
  CardKind? _initialAttachmentKind;
  String? _initialFileName;
  int? _initialFileSize;
  bool _initialSettled = false;
  bool _initialEmphasized = false;

  @override
  String get cardId => _cardId;

  @override
  String get collectionId => _collectionId;

  @override
  String get initialText => _initialText;

  @override
  CardKind get initialKind => _initialKind;

  @override
  String? get initialAttachmentId => _initialAttachmentId;

  @override
  List<String> get initialMoreAttachmentIds => _initialMoreAttachmentIds;

  @override
  CardKind? get initialAttachmentKind => _initialAttachmentKind;

  @override
  String? get initialFileName => _initialFileName;

  @override
  int? get initialFileSize => _initialFileSize;

  @override
  bool get initialSettled => _initialSettled;

  @override
  bool get initialEmphasized => _initialEmphasized;

  @override
  void open({
    required String cardId,
    required String collectionId,
    required String initialText,
    CardKind initialKind = CardKind.text,
    String? initialAttachmentId,
    List<String> initialMoreAttachmentIds = const [],
    CardKind? initialAttachmentKind,
    String? initialFileName,
    int? initialFileSize,
    bool initialSettled = false,
    bool initialEmphasized = false,
  }) {
    _cardId = cardId;
    _collectionId = collectionId;
    _initialText = initialText;
    _initialKind = initialKind;
    _initialAttachmentId = initialAttachmentId;
    _initialMoreAttachmentIds = initialMoreAttachmentIds;
    _initialAttachmentKind = initialAttachmentKind;
    _initialFileName = initialFileName;
    _initialFileSize = initialFileSize;
    _initialSettled = initialSettled;
    _initialEmphasized = initialEmphasized;
  }
}
