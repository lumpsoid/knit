import 'package:flutter/foundation.dart';
import 'package:knit/features/search/domain/search_filter.dart';
import 'package:knit/features/search/domain/search_models.dart';

enum SearchStatus { idle, loading, ready, failed }

/// The Search page's state — a [ChangeNotifier] the [SearchController] owns and
/// mutates, and the page listens to. [hits] holds the ranked hits for the last
/// submitted [query], already narrowed by [filter] and [scope].
class SearchState extends ChangeNotifier {
  SearchState({SearchScope? scope, SearchFilter filter = const SearchFilter()})
    : _scope = scope,
      _filter = filter;

  SearchStatus _status = SearchStatus.idle;
  String _query = '';
  SearchFilter _filter;
  SearchScope? _scope;
  List<SearchHit> _hits = const [];

  SearchStatus get status => _status;

  /// The last submitted query, as typed.
  String get query => _query;
  SearchFilter get filter => _filter;

  /// The collection the search is narrowed to (§4.2), or null for everything.
  SearchScope? get scope => _scope;
  List<SearchHit> get hits => _hits;

  void startLoading(String query) {
    _status = SearchStatus.loading;
    _query = query;
    notifyListeners();
  }

  void showResults(List<SearchHit> hits) {
    _status = SearchStatus.ready;
    _hits = hits;
    notifyListeners();
  }

  void showFailure() {
    _status = SearchStatus.failed;
    _hits = const [];
    notifyListeners();
  }

  /// Back to idle; the filter and scope stay for the next query.
  void reset() {
    _status = SearchStatus.idle;
    _query = '';
    _hits = const [];
    notifyListeners();
  }

  void setFilter(SearchFilter filter) {
    _filter = filter;
    notifyListeners();
  }

  void clearScope() {
    _scope = null;
    notifyListeners();
  }
}
