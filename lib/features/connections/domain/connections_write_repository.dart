import 'package:knit/features/connections/domain/connections_failure.dart';
import 'package:result_dart/result_dart.dart';

/// Narrow write port for the Connections view (business_logic.md §5). The only
/// mutation the view offers is clearing a broken link (spec §4.8 / §8.6.1) —
/// repair (re-point an endpoint) is a later concern.
abstract interface class ConnectionsWriteRepository {
  /// Clear (delete) a broken link. Only the `link` record is removed; the
  /// endpoints are untouched.
  Future<Result<String, ConnectionsFailure>> clearLink(String linkId);
}
