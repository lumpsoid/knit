import 'package:logging/logging.dart';
import 'package:knit/features/collection/presentation/collection_route_args.dart';
import 'package:knit/features/search/domain/search_models.dart';
import 'package:knit/features/search/domain/search_ranker.dart';
import 'package:knit/features/search/domain/search_read_repository.dart';
import 'package:knit/features/search/presentation/search_state.dart';

/// The Search page's input object (§3.2/§4.1): runs a submitted query over the
/// [SearchReadRepository] through the pure [SearchRanker], keeps the result in
/// [state], and writes the tapped hit into the Collection route-args carrier.
/// One per page instance — the page disposes it.
class SearchController {
  SearchController({
    required SearchReadRepository readRepository,
    required CollectionRouteArgsWriter collectionRouteArgs,
    SearchRanker ranker = const SearchRanker(),
    Logger? logger,
  }) : _read = readRepository,
       _routeArgs = collectionRouteArgs,
       _ranker = ranker,
       _log = logger ?? Logger('knit.search');

  final SearchReadRepository _read;
  final CollectionRouteArgsWriter _routeArgs;
  final SearchRanker _ranker;
  final Logger _log;

  final SearchState state = SearchState();

  /// Guards against an older, slower search overwriting a newer one.
  int _requestToken = 0;

  /// Search everything for [query]. A blank query clears the results.
  Future<void> submit(String query) async {
    final token = ++_requestToken;
    if (query.trim().isEmpty) {
      state.reset();
      return;
    }
    state.startLoading(query);
    final result = await _read.loadDocuments();
    if (token != _requestToken) return;
    result.fold(
      (documents) => state.showResults(_ranker.rank(query, documents)),
      (failure) {
        _log.severe('search failed', failure.error, failure.stackTrace);
        state.showFailure();
      },
    );
  }

  /// Re-run the last submitted query (the error view's retry).
  Future<void> retry() => submit(state.query);

  void setFilter(SearchFilter filter) => state.setFilter(filter);

  /// Point the Collection carrier at [hit] — its collection, plus the card to
  /// reveal for a card hit. The page navigates after this.
  void open(SearchHit hit) =>
      _routeArgs.open(hit.collectionId, focusCardId: hit.focusCardId);

  void dispose() {
    _requestToken++;
    state.dispose();
  }
}
