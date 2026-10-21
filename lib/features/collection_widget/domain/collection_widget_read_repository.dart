import 'package:knit/features/collection_widget/domain/collection_widget_failure.dart';
import 'package:knit/features/collection_widget/domain/collection_widget_models.dart';
import 'package:result_dart/result_dart.dart';

/// Narrow read port over the collections (business_logic.md §5).
abstract interface class CollectionWidgetReadRepository {
  /// Every live collection, most recently updated first (§8.6.3).
  Future<Result<List<CollectionWidgetTarget>, CollectionWidgetFailure>>
  loadTargets();

  /// The current title of each collection in [collectionIds] that is still
  /// live; deleted or unknown ids are absent from the map.
  Future<Result<Map<String, String>, CollectionWidgetFailure>> liveTitles(
    Set<String> collectionIds,
  );

  /// Of [collectionIds], the imported, read-only collections — no card can
  /// be added there, so their tiles offer no quick input.
  Future<Result<Set<String>, CollectionWidgetFailure>> readOnlyIds(
    Set<String> collectionIds,
  );
}
