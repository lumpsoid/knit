import 'dart:typed_data';

import 'package:knit/features/collection_share/domain/collection_share_failure.dart';
import 'package:knit/features/collection_share/domain/collection_share_models.dart';
import 'package:result_dart/result_dart.dart';

/// Imports a `.knitc` share file (docs/collection_share.md "Import").
abstract interface class CollectionShareImportRepository {
  /// Decode [bytes] and validate the whole file before anything is applied:
  /// signatures, authors, scope and the foreign-overwrite rule
  /// (`CollectionShareImportPolicy`). The plan carries the preview.
  Future<Result<CollectionShareImportPlan, CollectionShareFailure>> plan(
    Uint8List bytes,
  );

  /// Store the blobs by hash, then apply every op through the merge-core.
  /// Partial on a crash; importing again completes it (dedup by `op_id`).
  Future<Result<CollectionShareImportResult, CollectionShareFailure>> apply(
    CollectionShareImportPlan plan,
  );
}
