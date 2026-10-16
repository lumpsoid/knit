import 'package:knit/features/timeline/domain/timeline_failure.dart';
import 'package:knit/features/timeline/domain/timeline_pin_repository.dart';
import 'package:result_dart/result_dart.dart';

/// In-memory pin store for dev mode and tests — no platform channel, so it runs
/// anywhere. Holds the pinned set for the process lifetime; asserts the same
/// contract as the shared_preferences impl.
class InMemoryTimelinePinRepository
    implements TimelinePinReadRepository, TimelinePinWriteRepository {
  InMemoryTimelinePinRepository([Set<String> initial = const {}])
    : _pinned = {...initial};

  final Set<String> _pinned;

  @override
  Future<Result<Set<String>, TimelineFailure>> loadPinned() async =>
      Ok({..._pinned});

  @override
  Future<Result<Set<String>, TimelineFailure>> setPinned(
    String collectionId, {
    required bool pinned,
  }) async {
    if (pinned) {
      _pinned.add(collectionId);
    } else {
      _pinned.remove(collectionId);
    }
    return Ok({..._pinned});
  }
}
