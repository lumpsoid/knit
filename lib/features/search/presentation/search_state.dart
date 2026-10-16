import 'package:flutter/foundation.dart';
import 'package:knit/features/search/domain/search_models.dart';

enum SearchStatus { idle, loading, ready, failed }

/// The Search page's state — a [ChangeNotifier] the [SearchController] owns and
/// mutates, and the page listens to. [hits] holds every ranked hit for the last
/// submitted [query]; [visibleHits] is that list narrowed by [filter].
class SearchState extends ChangeNotifier {
  SearchStatus _status = SearchStatus.idle;
  String _query = '';
  SearchFilter _filter = SearchFilter.all;
  List<SearchHit> _hits = const [];

  SearchStatus get status => _status;

  /// The last submitted query, as typed.
  String get query => _query;
  SearchFilter get filter => _filter;
  List<SearchHit> get hits => _hits;

  List<SearchHit> get visibleHits => _filter == SearchFilter.all
      ? _hits
      : [
          for (final h in _hits)
            if (_filter.admits(h.kind)) h,
        ];

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

  void reset() {
    _status = SearchStatus.idle;
    _query = '';
    _hits = const [];
    notifyListeners();
  }

  void setFilter(SearchFilter filter) {
    if (filter == _filter) return;
    _filter = filter;
    notifyListeners();
  }
}
