import 'package:flutter/foundation.dart';

enum CollectionEditStatus { editing, saving, failed }

/// State for the Collection Edit page (§4.2/§4.3). The title + description being
/// edited live in page-owned [TextEditingController]s (seeded once from the
/// carrier), so a cover reload never disturbs unsaved text. [status] gates the
/// Save control. The cover image is managed in place (each change is its own
/// signed write, applied immediately) and reflected here.
@immutable
class CollectionEditState {
  const CollectionEditState({
    this.status = CollectionEditStatus.editing,
    this.collectionId = '',
    this.initialTitle = '',
    this.initialDescription,
    this.coverAttachmentId,
    this.coverBytes,
    this.coverBusy = false,
  });

  final CollectionEditStatus status;
  final String collectionId;
  final String initialTitle;
  final String? initialDescription;

  /// The collection's current cover image id (§7.4.1); null when it has none.
  final String? coverAttachmentId;

  /// Decoded bytes of the cover image, for [AttachmentImage]; null while
  /// loading/absent.
  final Uint8List? coverBytes;

  /// A cover add/replace/remove is in flight — gates the controls.
  final bool coverBusy;

  bool get hasCover => coverAttachmentId != null;

  static const Object _unset = Object();

  CollectionEditState copyWith({
    CollectionEditStatus? status,
    String? collectionId,
    String? initialTitle,
    Object? initialDescription = _unset,
    Object? coverAttachmentId = _unset,
    Object? coverBytes = _unset,
    bool? coverBusy,
  }) => CollectionEditState(
    status: status ?? this.status,
    collectionId: collectionId ?? this.collectionId,
    initialTitle: initialTitle ?? this.initialTitle,
    initialDescription: initialDescription == _unset
        ? this.initialDescription
        : initialDescription as String?,
    coverAttachmentId: coverAttachmentId == _unset
        ? this.coverAttachmentId
        : coverAttachmentId as String?,
    coverBytes: coverBytes == _unset
        ? this.coverBytes
        : coverBytes as Uint8List?,
    coverBusy: coverBusy ?? this.coverBusy,
  );
}
