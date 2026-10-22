import 'package:knit/core/files/domain/outgoing_file.dart';
import 'package:knit/features/collection_share/domain/collection_share_failure.dart';
import 'package:knit/features/collection_share/domain/collection_share_models.dart';
import 'package:result_dart/result_dart.dart';

/// Packages one collection as a `.knitc` share file: its winning signed ops
/// verbatim, with or without the attachment bytes, alone or with the own
/// collections its links reach.
abstract interface class CollectionShareExportRepository {
  /// The export sheet's numbers: title, card count, size with and without
  /// media and linked collections, and where its links point outside.
  Future<Result<CollectionShareEstimate, CollectionShareFailure>> estimate(
    String collectionId,
  );

  /// The finished file, named `<title>.knitc`.
  Future<Result<OutgoingFile, CollectionShareFailure>> export(
    String collectionId, {
    required bool includeMedia,
    bool includeLinked = false,
  });
}
