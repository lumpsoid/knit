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
    this.linkCollections,
    this.linkCardsByCollection = const {},
    this.reordering = false,
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

  /// Link-finder first level: live collections to link to (§4.4). Null until the
  /// finder is first opened; loaded lazily so opening a collection never reads
  /// every other collection's cards.
  final List<LinkOption>? linkCollections;

  /// Link-finder drilled level: a collection's cards, keyed by collection id.
  /// Filled on drill and reused within the session; the source card is excluded
  /// at render (the cache is source-card-independent). Cleared on feed reload.
  final Map<String, List<LinkOption>> linkCardsByCollection;

  /// Whether drag-to-reorder mode is active (§4.2).
  final bool reordering;

  bool get isEmpty => cards.isEmpty;

  bool get canReorder => cards.length > 1;

  CollectionState copyWith({
    CollectionStatus? status,
    String? collectionId,
    String? title,
    String? coverAttachmentId,
    List<FeedCard>? cards,
    Map<String, Uint8List>? imageBytes,
    List<LinkOption>? linkCollections,
    Map<String, List<LinkOption>>? linkCardsByCollection,
    bool? reordering,
  }) =>
      CollectionState(
        status: status ?? this.status,
        collectionId: collectionId ?? this.collectionId,
        title: title ?? this.title,
        coverAttachmentId: coverAttachmentId ?? this.coverAttachmentId,
        cards: cards ?? this.cards,
        imageBytes: imageBytes ?? this.imageBytes,
        linkCollections: linkCollections ?? this.linkCollections,
        linkCardsByCollection:
            linkCardsByCollection ?? this.linkCardsByCollection,
        reordering: reordering ?? this.reordering,
      );
}
