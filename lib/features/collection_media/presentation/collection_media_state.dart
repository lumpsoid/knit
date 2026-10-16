import 'package:flutter/foundation.dart';
import 'package:knit/features/collection_media/domain/collection_media_models.dart';

enum CollectionMediaStatus { loading, ready, failed }

/// State for the Collection Media page (§4.2). [media] is the read-only
/// overview; the photo thumbnails' bytes live in the shared image cache, which
/// the page reads directly.
@immutable
class CollectionMediaState {
  CollectionMediaState({
    this.status = CollectionMediaStatus.loading,
    this.collectionId = '',
    CollectionMedia? media,
  }) : media = media ?? CollectionMedia.empty;

  final CollectionMediaStatus status;
  final String collectionId;
  final CollectionMedia media;

  CollectionMediaState copyWith({
    CollectionMediaStatus? status,
    String? collectionId,
    CollectionMedia? media,
  }) => CollectionMediaState(
    status: status ?? this.status,
    collectionId: collectionId ?? this.collectionId,
    media: media ?? this.media,
  );
}
