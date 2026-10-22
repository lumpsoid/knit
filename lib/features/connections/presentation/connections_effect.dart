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

/// Remove the link [linkId] and its pair's duplicates (§4.4/§6.4); [ends]
/// is what an Undo re-links.
class RemoveLinkEffect extends ConnectionsEffect {
  const RemoveLinkEffect({required this.linkId, required this.ends});
  final String linkId;
  final LinkEnds ends;
}

/// Re-create a removed link between [ends] (the snackbar's Undo).
class RestoreLinkEffect extends ConnectionsEffect {
  const RestoreLinkEffect(this.ends);
  final LinkEnds ends;
}

/// Find the unlinked mentions of the collection [collectionId] titled [title]
/// (§8.6.5) — a separate step, after its links have rendered.
class LoadMentionsEffect extends ConnectionsEffect {
  const LoadMentionsEffect({required this.collectionId, required this.title});
  final String collectionId;
  final String title;
}

/// Link the card [cardId] to the collection [collectionId] (a signed link
/// create, §4.4).
class LinkMentionEffect extends ConnectionsEffect {
  const LinkMentionEffect({required this.cardId, required this.collectionId});
  final String cardId;
  final String collectionId;
}
