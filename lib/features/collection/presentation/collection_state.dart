import 'package:flutter/foundation.dart';
import 'package:knit/features/collection/domain/collection_models.dart';

enum CollectionStatus { loading, ready, failed }

/// State for the Collection screen (§4.2). [reordering] is the *mode* of this
/// screen (drag-to-reorder), not a separate screen — exactly as the spec frames
/// it. Sheets/dialogs (compose, add-block, actions, finder, edit) are transient
/// View concerns that dispatch intents; they are not modelled here.
@immutable
class CollectionState {
  const CollectionState({
    this.status = CollectionStatus.loading,
    this.collectionId = '',
    this.title = '',
    this.coverAttachmentId,
    this.cards = const [],
    this.imageBytes = const {},
    this.linkTargets = const [],
    this.reordering = false,
    this.errorMessage,
  });

  final CollectionStatus status;
  final String collectionId;
  final String title;
  final String? coverAttachmentId;
  final List<FeedCard> cards;

  /// Decoded bytes of image cards, keyed by `attachment_id`. Content-addressed,
  /// so an id's bytes are immutable — cached here to avoid reloading on every
  /// rebuild (and preserved across feed reloads). Absent ⇒ loading or missing,
  /// which renders the placeholder fallback.
  final Map<String, Uint8List> imageBytes;

  /// Other collections this card can be linked to, in the finder sheet (§4.2).
  final List<LinkCandidate> linkTargets;

  /// Whether drag-to-reorder mode is active (§4.2).
  final bool reordering;

  final String? errorMessage;

  bool get isEmpty => cards.isEmpty;

  CollectionState copyWith({
    CollectionStatus? status,
    String? collectionId,
    String? title,
    String? coverAttachmentId,
    List<FeedCard>? cards,
    Map<String, Uint8List>? imageBytes,
    List<LinkCandidate>? linkTargets,
    bool? reordering,
    String? errorMessage,
  }) =>
      CollectionState(
        status: status ?? this.status,
        collectionId: collectionId ?? this.collectionId,
        title: title ?? this.title,
        coverAttachmentId: coverAttachmentId ?? this.coverAttachmentId,
        cards: cards ?? this.cards,
        imageBytes: imageBytes ?? this.imageBytes,
        linkTargets: linkTargets ?? this.linkTargets,
        reordering: reordering ?? this.reordering,
        errorMessage: errorMessage ?? this.errorMessage,
      );
}
