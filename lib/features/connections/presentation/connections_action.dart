import 'package:knit/features/connections/domain/connections_models.dart';
import 'package:knit/features/connections/domain/unlinked_mentions.dart';

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

/// A row's ⋮ → Remove: delete its link, every duplicate of the pair with it
/// (§4.4/§6.4). Only a [ConnectionItem.removable] row offers it.
class RemoveLinkRequested extends ConnectionsAction {
  const RemoveLinkRequested(this.item);
  final ConnectionItem item;
}

/// The "Link removed" snackbar's Undo → link the same two ends again.
class UndoRemoveLinkRequested extends ConnectionsAction {
  const UndoRemoveLinkRequested(this.ends);
  final LinkEnds ends;
}

/// The "Mentioned in" rows (§4.4, §8.6.5) for the collection [collectionId],
/// read after its links. Dropped when the focus has moved on since.
class MentionsLoaded extends ConnectionsAction {
  const MentionsLoaded({required this.collectionId, required this.mentions});
  final String collectionId;
  final UnlinkedMentions mentions;
}

/// "Link" on a mention row → link that card to the focused collection.
class LinkMentionRequested extends ConnectionsAction {
  const LinkMentionRequested(this.cardId);
  final String cardId;
}

class DeactivateFeature extends ConnectionsAction {
  const DeactivateFeature();
}
