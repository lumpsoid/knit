import 'package:knit/features/search/domain/search_failure.dart';
import 'package:knit/features/search/domain/search_models.dart';
import 'package:result_dart/result_dart.dart';

/// Narrow read port for Search (business_logic.md §5): every live collection
/// and card, flattened to its searchable texts. Matching and ranking happen in
/// the pure [SearchRanker], so a faster backing (e.g. an FTS index) can replace
/// this port without touching the ranking rules.
abstract interface class SearchReadRepository {
  Future<Result<List<SearchDocument>, SearchFailure>> loadDocuments();
}
