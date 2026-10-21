import 'package:knit/sync/snapshot.dart';

/// One entity a fork creates: its new [id], its full [content] and, for a
/// card, its [position].
class ForkEntity {
  const ForkEntity({
    required this.type,
    required this.id,
    required this.content,
    this.position,
  }) : assert(
         (type == EntityType.card) == (position != null),
         'cards need a position; non-cards must not pass one',
       );

  final EntityType type;
  final String id;
  final Map<String, Object?> content;
  final String? position;
}

/// The entities "Save a copy" creates (§10.5 fork), in write order. Planned
/// purely by the share feature's `ForkPlanner`; [SyncStore.forkCollection]
/// writes them all in one transaction.
class ForkPlan {
  const ForkPlan({required this.collectionId, required this.entities});

  /// The new collection's id.
  final String collectionId;

  final List<ForkEntity> entities;
}
