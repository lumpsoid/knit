import 'dart:typed_data';

import 'package:knit/sync/sync.dart';

/// The share file's format tag, version, extension and mime
/// (docs/collection_share.md "The file").
const String kCollectionShareFormat = 'knit-collection';
const int kCollectionShareVersion = 1;
const String kCollectionShareExtension = 'knitc';
const String kCollectionShareMime = 'application/vnd.knit.collection+zip';

/// The file header. [title] and [cardCount] are an unsigned preview only:
/// the import never trusts them, it reads the verified ops.
class CollectionShareManifest {
  const CollectionShareManifest({
    required this.createdAtMs,
    required this.collectionId,
    required this.owner,
    required this.title,
    required this.cardCount,
    required this.opCount,
    required this.blobCount,
    required this.mediaIncluded,
    this.format = kCollectionShareFormat,
    this.version = kCollectionShareVersion,
  });

  factory CollectionShareManifest.fromJson(Map<String, Object?> json) =>
      CollectionShareManifest(
        format: json['format'] as String? ?? '',
        version: (json['version'] as num?)?.toInt() ?? 0,
        createdAtMs: (json['createdAtMs'] as num?)?.toInt() ?? 0,
        collectionId: json['collectionId'] as String? ?? '',
        owner: json['owner'] as String? ?? '',
        title: json['title'] as String? ?? '',
        cardCount: (json['cardCount'] as num?)?.toInt() ?? 0,
        opCount: (json['opCount'] as num?)?.toInt() ?? 0,
        blobCount: (json['blobCount'] as num?)?.toInt() ?? 0,
        mediaIncluded: json['mediaIncluded'] as bool? ?? false,
      );

  final String format;
  final int version;
  final int createdAtMs;
  final String collectionId;

  /// The collection creator's pubkey.
  final String owner;
  final String title;
  final int cardCount;
  final int opCount;
  final int blobCount;
  final bool mediaIncluded;

  Map<String, Object?> toJson() => {
    'format': format,
    'version': version,
    'createdAtMs': createdAtMs,
    'collectionId': collectionId,
    'owner': owner,
    'title': title,
    'cardCount': cardCount,
    'opCount': opCount,
    'blobCount': blobCount,
    'mediaIncluded': mediaIncluded,
  };
}

/// A decoded share file: its [manifest], the signed [ops] verbatim and the
/// attachment [blobs] by content hash (empty without media).
class CollectionShareBundle {
  const CollectionShareBundle({
    required this.manifest,
    required this.ops,
    required this.blobs,
  });

  final CollectionShareManifest manifest;
  final List<PersistedOp> ops;
  final Map<String, Uint8List> blobs;
}

/// What the export sheet shows before sending: the file size with and
/// without the media.
class CollectionShareEstimate {
  const CollectionShareEstimate({
    required this.title,
    required this.cardCount,
    required this.baseBytes,
    required this.mediaBytes,
    required this.mediaCount,
  });

  final String title;
  final int cardCount;

  /// The ops alone.
  final int baseBytes;

  /// The attachment bytes "Include media" adds.
  final int mediaBytes;
  final int mediaCount;

  int sizeWith({required bool media}) =>
      media ? baseBytes + mediaBytes : baseBytes;
}

/// A validated file, ready to import, and what the preview sheet shows:
/// "Trip to Kyoto · 24 cards · from mira#9f86 · media not included".
class CollectionShareImportPlan {
  const CollectionShareImportPlan({
    required this.bundle,
    required this.title,
    required this.cardCount,
    required this.ownerNickname,
    required this.ownerFingerprint,
    required this.isUpdate,
    required this.isOwn,
  });

  final CollectionShareBundle bundle;

  /// From the verified ops, not the manifest.
  final String title;
  final int cardCount;
  final String? ownerNickname;
  final String ownerFingerprint;

  /// The collection is already on this device ("Update" instead of
  /// "Import").
  final bool isUpdate;

  /// The file is this identity's own (a mini-restore, editable).
  final bool isOwn;

  String get collectionId => bundle.manifest.collectionId;
  bool get mediaIncluded => bundle.manifest.mediaIncluded;
}

/// The outcome of an import.
class CollectionShareImportResult {
  const CollectionShareImportResult({
    required this.collectionId,
    required this.opsApplied,
    required this.opsDeduped,
    required this.blobsRestored,
  });

  final String collectionId;
  final int opsApplied;
  final int opsDeduped;
  final int blobsRestored;
}
