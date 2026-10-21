import 'package:knit/features/collection_share/domain/collection_share_models.dart';

/// Recognizes a collection share file among incoming files: by its mime, or
/// — since most senders label an unknown type `application/octet-stream` —
/// by its `.knitc` name.
abstract final class CollectionShareFiles {
  static bool matches({required String name, required String? mime}) =>
      mime == kCollectionShareMime ||
      name.toLowerCase().endsWith('.$kCollectionShareExtension');
}
