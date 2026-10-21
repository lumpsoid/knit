import 'package:knit/features/collection_present/domain/present_failure.dart';
import 'package:knit/features/collection_present/domain/present_progress_repository.dart';
import 'package:result_dart/result_dart.dart';

/// In-memory progress store for dev mode and tests — no platform channel. Holds
/// the remembered cards for the process lifetime.
class InMemoryPresentProgressRepository
    implements PresentProgressReadRepository, PresentProgressWriteRepository {
  InMemoryPresentProgressRepository([Map<String, String> initial = const {}])
    : anchors = {...initial};

  final Map<String, String> anchors;

  @override
  Future<Result<String?, PresentFailure>> loadAnchor(
    String collectionId,
  ) async => Ok(anchors[collectionId]);

  @override
  Future<Result<void, PresentFailure>> saveAnchor(
    String collectionId,
    String? anchorCardId,
  ) async {
    if (anchorCardId == null) {
      anchors.remove(collectionId);
    } else {
      anchors[collectionId] = anchorCardId;
    }
    return const Ok<void, PresentFailure>(null);
  }
}
