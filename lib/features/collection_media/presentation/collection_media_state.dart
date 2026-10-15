import 'package:flutter/foundation.dart';
import 'package:knit/features/collection_media/domain/collection_media_models.dart';

enum CollectionMediaStatus { loading, ready, failed }

/// State for the Collection Media page (§4.2). [media] is the read-only overview;
/// [photoBytes] caches decoded thumbnails by `attachment_id` (content-addressed,
/// so an id's bytes never change) and [missingPhotos] marks blobs not on this
/// device, so their tiles show a placeholder instead of a spinner.
@immutable
class CollectionMediaState {
  CollectionMediaState({
    this.status = CollectionMediaStatus.loading,
    this.collectionId = '',
    CollectionMedia? media,
    this.photoBytes = const {},
    this.missingPhotos = const {},
  }) : media = media ?? CollectionMedia.empty;

  final CollectionMediaStatus status;
  final String collectionId;
  final CollectionMedia media;
  final Map<String, Uint8List> photoBytes;
  final Set<String> missingPhotos;

  CollectionMediaState copyWith({
    CollectionMediaStatus? status,
    String? collectionId,
    CollectionMedia? media,
    Map<String, Uint8List>? photoBytes,
    Set<String>? missingPhotos,
  }) => CollectionMediaState(
    status: status ?? this.status,
    collectionId: collectionId ?? this.collectionId,
    media: media ?? this.media,
    photoBytes: photoBytes ?? this.photoBytes,
    missingPhotos: missingPhotos ?? this.missingPhotos,
  );
}
