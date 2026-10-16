import 'package:flutter/foundation.dart';
import 'package:knit/features/collection_media/domain/collection_media_models.dart';

enum CollectionEditStatus { editing, saving, failed }

/// State for the Collection Edit page (§4.2): the save status, the cover
/// section's in-flight flag, and the media summary. The header itself (title,
/// description, cover id) is the shared collection details and the image bytes
/// the shared image cache, which the page reads directly.
@immutable
class CollectionEditState {
  const CollectionEditState({
    this.status = CollectionEditStatus.editing,
    this.collectionId = '',
    this.coverBusy = false,
    this.mediaCounts,
    this.mediaPreviewIds = const [],
  });

  final CollectionEditStatus status;
  final String collectionId;

  /// A cover pick/remove is in flight.
  final bool coverBusy;

  /// Per-kind media counts; null until the summary loads (the row stays hidden).
  final MediaCounts? mediaCounts;

  /// Attachment ids of the newest photos for the summary's thumbnail strip;
  /// their bytes come from the shared image cache.
  final List<String> mediaPreviewIds;

  CollectionEditState copyWith({
    CollectionEditStatus? status,
    String? collectionId,
    bool? coverBusy,
    MediaCounts? mediaCounts,
    List<String>? mediaPreviewIds,
  }) => CollectionEditState(
    status: status ?? this.status,
    collectionId: collectionId ?? this.collectionId,
    coverBusy: coverBusy ?? this.coverBusy,
    mediaCounts: mediaCounts ?? this.mediaCounts,
    mediaPreviewIds: mediaPreviewIds ?? this.mediaPreviewIds,
  );
}
