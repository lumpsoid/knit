import 'package:knit/features/collection_media/domain/collection_media_failure.dart';
import 'package:knit/features/collection_media/domain/collection_media_models.dart';
import 'package:result_dart/result_dart.dart';

/// Narrow read port for the Collection Media overview (business_logic.md §5):
/// the media cards (photo/audio/file/link) of one collection. Read-only — the
/// overview never writes; edits go through the Card Edit page.
abstract interface class CollectionMediaReadRepository {
  Future<Result<CollectionMedia, CollectionMediaFailure>> loadMedia(
    String collectionId,
  );
}
