import 'package:knit/core/ids/id_generator.dart';
import 'package:knit/sync/sync.dart';

/// The live rows a copy is made from: one collection with its live cards,
/// the live links sourced at it or at those cards, and the live attachments
/// they reference.
class ForkSource {
  const ForkSource({
    required this.collection,
    required this.cards,
    required this.links,
    required this.attachments,
  });

  final Snapshot collection;
  final List<Snapshot> cards;
  final List<Snapshot> links;
  final List<Snapshot> attachments;
}

/// Plans "Save a copy" (§10.5 fork, docs/collection_share.md): every entity
/// gets a new id, intra-set link endpoints are rewritten, links that point
/// outside keep their targets, attachments keep their `content_hash` (so no
/// bytes are copied). Positions and the settled / emphasized marks are kept;
/// `archived_at` is cleared. Pure — the store stamps author, `created_by`,
/// `created_at` and the HLC when it writes the plan.
class ForkPlanner {
  const ForkPlanner({required IdGenerator ids}) : _ids = ids;

  final IdGenerator _ids;

  ForkPlan plan(ForkSource source) {
    final newIds = <String, String>{
      source.collection.id: _ids.newId(),
      for (final a in source.attachments) a.id: _ids.newId(),
      for (final c in source.cards) c.id: _ids.newId(),
    };
    String? mapped(Object? id) => id is String ? newIds[id] : null;
    final collectionId = newIds[source.collection.id]!;

    return ForkPlan(
      collectionId: collectionId,
      entities: [
        for (final a in source.attachments)
          ForkEntity(
            type: EntityType.attachment,
            id: newIds[a.id]!,
            content: a.content,
          ),
        ForkEntity(
          type: EntityType.collection,
          id: collectionId,
          content: {
            ...source.collection.content,
            CollectionSchema.colCoverAttachmentId: mapped(
              source.collection.content[CollectionSchema.colCoverAttachmentId],
            ),
            CollectionSchema.colArchivedAt: null,
          },
        ),
        for (final c in source.cards)
          ForkEntity(
            type: EntityType.card,
            id: newIds[c.id]!,
            position: c.position,
            content: {
              ...c.content,
              CardSchema.colCollectionId: collectionId,
              CardSchema.colAttachmentId: mapped(
                c.content[CardSchema.colAttachmentId],
              ),
              CardSchema.colMoreAttachmentIds:
                  CardSchema.encodeMoreAttachmentIds([
                    for (final id in CardSchema.decodeMoreAttachmentIds(
                      c.content[CardSchema.colMoreAttachmentIds],
                    ))
                      ?mapped(id),
                  ]),
            },
          ),
        for (final l in source.links)
          if (mapped(l.content[LinkSchema.colSourceId]) case final sourceId?)
            ForkEntity(
              type: EntityType.link,
              id: _ids.newId(),
              content: {
                ...l.content,
                LinkSchema.colSourceId: sourceId,
                LinkSchema.colTargetId:
                    mapped(l.content[LinkSchema.colTargetId]) ??
                    l.content[LinkSchema.colTargetId],
              },
            ),
      ],
    );
  }
}
