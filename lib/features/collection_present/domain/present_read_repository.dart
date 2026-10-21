import 'package:knit/features/collection_present/domain/present_failure.dart';
import 'package:knit/features/collection_present/domain/present_models.dart';
import 'package:result_dart/result_dart.dart';

/// Narrow read port for presenting a collection (§4.9, business_logic.md §5):
/// its header and every live card in feed order, each with its live links.
abstract interface class PresentReadRepository {
  Future<Result<PresentSource, PresentFailure>> loadSource(String collectionId);
}
