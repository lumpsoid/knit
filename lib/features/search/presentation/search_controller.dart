import 'dart:async';

import 'package:logging/logging.dart';
import 'package:knit/features/collection/presentation/collection_route_args.dart';
import 'package:knit/features/search/domain/search_filter.dart';
import 'package:knit/features/search/domain/search_models.dart';
import 'package:knit/features/search/domain/search_ranker.dart';
import 'package:knit/features/search/domain/search_read_repository.dart';
import 'package:knit/features/search/presentation/search_state.dart';

/// The Search page's input object (§3.2/§4.1): runs a submitted query over the
/// [SearchReadRepository] through the pure [SearchFilter] and [SearchRanker],
/// keeps the result in [state], and writes the tapped hit into the Collection
/// route-args carrier. A [scope] (§4.2: opened from a collection) narrows the
/// search to that collection's cards until it is cleared, and remains the
/// origin a hit inside it returns to. One per page instance — the page
/// disposes it.
class SearchController {
  SearchController({
    required SearchReadRepository readRepository,
    required CollectionRouteArgsWriter collectionRouteArgs,
    SearchScope? scope,
    SearchRanker ranker = const SearchRanker(),
    Logger? logger,
  }) : _read = readRepository,
       _routeArgs = collectionRouteArgs,
       _origin = scope,
       _ranker = ranker,
       _log = logger ?? Logger('knit.search'),
       state = SearchState(scope: scope);

  final SearchReadRepository _read;
  final CollectionRouteArgsWriter _routeArgs;
  final SearchScope? _origin;
  final SearchRanker _ranker;
  final Logger _log;

  final SearchState state;

  /// The documents of the last successful load, re-ranked when a filter or
  /// the scope changes so those never re-read the corpus.
  List<SearchDocument>? _documents;

  /// Guards against an older, slower search overwriting a newer one.
  int _requestToken = 0;

  /// Search for [query]. A blank query clears the results.
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
      (documents) {
        _documents = documents;
        _showResults(documents);
      },
      (failure) {
        _log.severe('search failed', failure.error, failure.stackTrace);
        state.showFailure();
      },
    );
  }

  /// Re-run the last submitted query (the error view's retry).
  Future<void> retry() => submit(state.query);

  void setResultType(SearchResultType type) =>
      _refilter(state.filter.copyWith(type: type));

  void toggleKind(SearchCardKind kind) =>
      _refilter(state.filter.toggleKind(kind));

  void cycleSettled() =>
      _refilter(state.filter.copyWith(settled: state.filter.settled.next));

  void setIncludeArchived(bool include) =>
      _refilter(state.filter.copyWith(includeArchived: include));

  /// Widen a scoped search to everything (the scope chip's ✕).
  void clearScope() {
    if (state.scope == null) return;
    state.clearScope();
    _rerun();
  }

  /// Where [hit] leads. A hit outside the origin collection points the
  /// Collection carrier at its collection (plus the card to reveal); the page
  /// navigates after this.
  SearchDestination open(SearchHit hit) {
    final destination = SearchDestination.of(hit, origin: _origin);
    if (destination is OpenCollection) {
      _routeArgs.open(hit.collectionId, focusCardId: hit.focusCardId);
    }
    return destination;
  }

  void dispose() {
    _requestToken++;
    state.dispose();
  }

  void _refilter(SearchFilter filter) {
    state.setFilter(filter);
    _rerun();
  }

  /// Apply a changed filter or scope to the last submitted query: re-rank the
  /// held documents, or re-run a failed search. Idle has nothing to re-run,
  /// and a load in flight ranks with the new filter when it lands.
  void _rerun() {
    switch (state.status) {
      case SearchStatus.ready:
        final documents = _documents;
        if (documents != null) {
          _showResults(documents);
        } else {
          unawaited(retry());
        }
      case SearchStatus.failed:
        unawaited(retry());
      case SearchStatus.idle || SearchStatus.loading:
        break;
    }
  }

  void _showResults(List<SearchDocument> documents) => state.showResults(
    _ranker.rank(
      state.query,
      state.filter.narrow(documents, scope: state.scope),
    ),
  );
}
