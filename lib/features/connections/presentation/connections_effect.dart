import 'package:knit/features/connections/domain/connections_models.dart';

/// Async-work descriptors for the Connections view (fcis.md §6.4).
sealed class ConnectionsEffect {
  const ConnectionsEffect();
}

/// Read the links-out + backlinks (with endpoint liveness, §8.6.1) for one
/// entity.
class LoadConnectionsEffect extends ConnectionsEffect {
  const LoadConnectionsEffect({required this.kind, required this.id});
  final ConnectedEntityKind kind;
  final String id;
}

/// Clear (delete) a broken link (spec §4.8 / §8.6.1).
class ClearLinkEffect extends ConnectionsEffect {
  const ClearLinkEffect(this.linkId);
  final String linkId;
}
