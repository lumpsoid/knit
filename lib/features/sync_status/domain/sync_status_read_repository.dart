import 'package:knit/features/sync_status/domain/sync_status_failure.dart';
import 'package:result_dart/result_dart.dart';

/// Narrow read port for the sync indicator (business_logic.md §5): the count of
/// local ops not yet acked by a relay (§6.6). Relay-less today, so this is the
/// count of everything written on this device.
abstract interface class SyncStatusReadRepository {
  Future<Result<int, SyncStatusFailure>> pendingCount();
}
