import 'dart:typed_data';

import 'package:knit/sync/sync.dart';

/// The share file's format tag, version, extension and mime
/// (docs/collection_share.md "The file"). A file with linked collections is
/// version [kCollectionShareVersion]; one without stays
/// [kCollectionShareSingleVersion], so an older Knit still opens it, and
/// refuses a multi-collection file as "from a newer Knit" instead of
/// misreading it.
const String kCollectionShareFormat = 'knit-collection';
const int kCollectionShareVersion = 2;
const int kCollectionShareSingleVersion = 1;
const String kCollectionShareExtension = 'knitc';
const String kCollectionShareMime = 'application/vnd.knit.collection+zip';

/// The file header: the primary collection, plus the linked collections
/// bundled alongside it ([included]). [title] and [cardCount] are an unsigned
/// preview only: the import never trusts them, it reads the verified ops.
class CollectionShareManifest {
  CollectionShareManifest({
    required this.createdAtMs,
    required this.collectionId,
    required this.owner,
    required this.title,
    required this.cardCount,
    required this.opCount,
    required this.blobCount,
    required this.mediaIncluded,
    this.included = const [],
    this.format = kCollectionShareFormat,
    int? version,
  }) : version =
           version ??
           (included.isEmpty
               ? kCollectionShareSingleVersion
               : kCollectionShareVersion);

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
        included: [
          for (final entry in json['included'] as List<Object?>? ?? const [])
            CollectionShareEntry.fromJson(entry! as Map<String, Object?>),
        ],
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

  /// The linked collections the file also carries, one level deep. Empty in
  /// a single-collection (version 1) file.
  final List<CollectionShareEntry> included;

  /// Every collection in the file, the primary first: id → its owner.
  Map<String, String> get owners => {
    collectionId: owner,
    for (final entry in included) entry.collectionId: entry.owner,
  };

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
    if (included.isNotEmpty)
      'included': [for (final entry in included) entry.toJson()],
  };
}

/// One linked collection in a manifest: its id, its creator's pubkey, and an
/// unsigned [title] / [cardCount] preview.
class CollectionShareEntry {
  const CollectionShareEntry({
    required this.collectionId,
    required this.owner,
    required this.title,
    required this.cardCount,
  });

  factory CollectionShareEntry.fromJson(Map<String, Object?> json) =>
      CollectionShareEntry(
        collectionId: json['collectionId'] as String? ?? '',
        owner: json['owner'] as String? ?? '',
        title: json['title'] as String? ?? '',
        cardCount: (json['cardCount'] as num?)?.toInt() ?? 0,
      );

  final String collectionId;
  final String owner;
  final String title;
  final int cardCount;

  Map<String, Object?> toJson() => {
    'collectionId': collectionId,
    'owner': owner,
    'title': title,
    'cardCount': cardCount,
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

/// A file's size before sending: the ops alone, and the attachment bytes
/// "Include media" adds.
class ShareSize {
  const ShareSize({
    required this.baseBytes,
    required this.mediaBytes,
    required this.mediaCount,
  });

  /// The ops alone.
  final int baseBytes;

  /// The attachment bytes "Include media" adds.
  final int mediaBytes;
  final int mediaCount;

  int sizeWith({required bool media}) =>
      media ? baseBytes + mediaBytes : baseBytes;
}

/// What the export sheet shows before sending: the file size with and
/// without the media, alone and with the linked collections, and where the
/// collection's links point outside it.
class CollectionShareEstimate {
  const CollectionShareEstimate({
    required this.title,
    required this.cardCount,
    required this.alone,
    required this.withLinked,
    required this.reach,
  });

  final String title;
  final int cardCount;

  /// The collection by itself.
  final ShareSize alone;

  /// With "Include linked collections" on (the same as [alone] when there
  /// are none).
  final ShareSize withLinked;

  /// The outside links: the warning's counts and the collections to bundle.
  final ShareReach reach;

  ShareSize sizeFor({required bool linked}) => linked ? withLinked : alone;
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

  /// The linked collections the file carries besides the primary one.
  int get linkedCollectionCount => bundle.manifest.included.length;
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
