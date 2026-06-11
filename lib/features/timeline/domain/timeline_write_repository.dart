import 'package:knit/features/timeline/domain/timeline_failure.dart';
import 'package:result_dart/result_dart.dart';

/// Narrow write port for the timeline (business_logic.md §5). The only write
/// the home screen performs is inline collection creation (§4.1); on success it
/// returns the new collection's id so the View can open it.
abstract interface class TimelineWriteRepository {
  Future<Result<String, TimelineFailure>> createCollection(String title);
}
