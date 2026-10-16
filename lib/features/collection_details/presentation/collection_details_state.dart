import 'package:flutter/foundation.dart';
import 'package:knit/features/collection_details/domain/collection_details.dart';

/// The app-wide collection-header state — a [ChangeNotifier] the
/// [CollectionDetailsController] owns and mutates, and every page that shows a
/// collection's title, description or cover listens to (the Timeline, the
/// Collection screen, the Collection Edit page). One entry per collection seen
/// this session, refreshed whenever a feature reads it from the projection.
class CollectionDetailsState extends ChangeNotifier {
  final Map<String, CollectionDetails> _byId = {};

  /// The known header of [collectionId], or null before anything has read it.
  CollectionDetails? of(String collectionId) => _byId[collectionId];

  /// Store [details], replacing any older copy. Notifies only on a change.
  void put(CollectionDetails details) {
    if (_byId[details.collectionId] == details) return;
    _byId[details.collectionId] = details;
    notifyListeners();
  }

  /// Store every entry of [all] with a single notification.
  void putAll(Iterable<CollectionDetails> all) {
    var changed = false;
    for (final details in all) {
      if (_byId[details.collectionId] == details) continue;
      _byId[details.collectionId] = details;
      changed = true;
    }
    if (changed) notifyListeners();
  }
}
