import 'package:knit/features/connections/domain/connections_failure.dart';
import 'package:knit/features/connections/domain/connections_models.dart';
import 'package:result_dart/result_dart.dart';

/// Narrow read port for the Connections view (business_logic.md §5). Loads one
/// entity's links-out + linked-from (backlinks) with each far endpoint's
/// liveness already resolved (§8.6.1/§8.6.2), in one shot.
abstract interface class ConnectionsReadRepository {
  Future<Result<ConnectionsData, ConnectionsFailure>> loadConnections(
    ConnectedEntityKind kind,
    String id,
  );
}
