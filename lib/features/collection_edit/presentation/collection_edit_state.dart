import 'package:flutter/foundation.dart';
import 'package:knit/features/collection_media/domain/collection_media_models.dart';

enum CollectionEditStatus { editing, saving, failed }

/// State for the Collection Edit page (§4.2): the save status plus the cover
/// section's decoded preview + in-flight flag, and the media summary. The
/// header itself (title, description, cover id) is the shared collection
/// details, which the page reads directly.
@immutable
class CollectionEditState {
  const CollectionEditState({
    this.status = CollectionEditStatus.editing,
    this.collectionId = '',
    this.coverBytes,
    this.coverBusy = false,
    this.mediaCounts,
    this.mediaPreviews = const [],
  });

  final CollectionEditStatus status;
  final String collectionId;

  /// The current cover's decoded bytes for the preview; null while loading or
  /// when there is no cover.
  final Uint8List? coverBytes;

  /// A cover pick/remove (or the initial cover load) is in flight.
  final bool coverBusy;

  /// Per-kind media counts; null until the summary loads (the row stays hidden).
  final MediaCounts? mediaCounts;

  /// Decoded bytes of the newest photos for the summary's thumbnail strip.
  final List<Uint8List> mediaPreviews;

  static const Object _unset = Object();

  CollectionEditState copyWith({
    CollectionEditStatus? status,
    String? collectionId,
    Object? coverBytes = _unset,
    bool? coverBusy,
    MediaCounts? mediaCounts,
    List<Uint8List>? mediaPreviews,
  }) => CollectionEditState(
    status: status ?? this.status,
    collectionId: collectionId ?? this.collectionId,
    coverBytes: coverBytes == _unset
        ? this.coverBytes
        : coverBytes as Uint8List?,
    coverBusy: coverBusy ?? this.coverBusy,
    mediaCounts: mediaCounts ?? this.mediaCounts,
    mediaPreviews: mediaPreviews ?? this.mediaPreviews,
  );
}
