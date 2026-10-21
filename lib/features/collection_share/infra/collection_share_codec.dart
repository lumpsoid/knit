import 'dart:convert';
import 'dart:typed_data';

import 'package:knit/core/files/infra/log_archive.dart';
import 'package:knit/features/collection_share/domain/collection_share_models.dart';
import 'package:knit/sync/sync.dart';

/// Thrown by [CollectionShareCodec.decode] for a file made by a newer Knit.
class NewerShareVersionException implements Exception {
  const NewerShareVersionException(this.version);

  final int version;

  @override
  String toString() => 'NewerShareVersionException(version $version)';
}

/// Pure zip (de)serialization of the `.knitc` share file, over the shared
/// [LogArchive] layout (the backup bundle's shape, its own format tag).
class CollectionShareCodec {
  const CollectionShareCodec();

  Uint8List encode(CollectionShareBundle bundle) => LogArchive.encode(
    LogArchiveEntries(
      manifest: bundle.manifest.toJson(),
      opLines: [for (final op in bundle.ops) jsonEncode(op.toDb())],
      blobs: bundle.blobs,
    ),
  );

  /// Decode a share file. Throws [NewerShareVersionException] for a newer
  /// version and [FormatException] when the bytes are not a Knit collection
  /// file or an op line does not parse.
  CollectionShareBundle decode(Uint8List bytes) {
    final entries = LogArchive.decode(bytes);
    final manifest = CollectionShareManifest.fromJson(entries.manifest);
    if (manifest.format != kCollectionShareFormat) {
      throw FormatException('not a Knit collection: "${manifest.format}"');
    }
    if (manifest.version > kCollectionShareVersion) {
      throw NewerShareVersionException(manifest.version);
    }
    final ops = <PersistedOp>[];
    for (final line in entries.opLines) {
      try {
        final op = PersistedOp.fromDb(jsonDecode(line) as Map<String, Object?>);
        op.toSnapshot(); // the payload must parse too
        ops.add(op);
      } on Object {
        throw const FormatException('unreadable op line');
      }
    }
    return CollectionShareBundle(
      manifest: manifest,
      ops: ops,
      blobs: entries.blobs,
    );
  }
}
