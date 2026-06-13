import 'package:knit/features/connections/domain/connections_models.dart';

/// Intents + async-result deliveries for the Connections view (fcis.md §6.4).
/// All payloads are scalars / feature-local view-models (no sync-core types).
sealed class ConnectionsAction {
  const ConnectionsAction();
}

/// View attached for a root entity (read from the route-args carrier, §2).
class ViewAttached extends ConnectionsAction {
  const ViewAttached({
    required this.kind,
    required this.id,
    required this.title,
  });
  final ConnectedEntityKind kind;
  final String id;
  final String title;
}

/// Re-read the current focus silently (pull-to-refresh and post-clear resync).
class ReloadRequested extends ConnectionsAction {
  const ReloadRequested();
}

class ConnectionsLoaded extends ConnectionsAction {
  const ConnectionsLoaded(this.data);
  final ConnectionsData data;
}

class LoadFailed extends ConnectionsAction {
  const LoadFailed();
}

/// Tap a live connection → jump to its far endpoint, pushing a breadcrumb (§4.4).
/// A broken connection is never tapped (the page disables the jump).
class ConnectionTapped extends ConnectionsAction {
  const ConnectionTapped(this.item);
  final ConnectionItem item;
}

/// Tap a breadcrumb → jump back to that depth in the back-stack (§4.4).
class CrumbTapped extends ConnectionsAction {
  const CrumbTapped(this.index);
  final int index;
}

/// Pop one breadcrumb hop (the hardware/app-bar back when not at the root).
class BackRequested extends ConnectionsAction {
  const BackRequested();
}

/// Broken-link chip → clear (delete) the link (spec §4.8 / §8.6.1).
class ClearLinkRequested extends ConnectionsAction {
  const ClearLinkRequested(this.linkId);
  final String linkId;
}

class DeactivateFeature extends ConnectionsAction {
  const DeactivateFeature();
}
