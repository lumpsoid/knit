import 'package:knit/app/app_graph.dart';
import 'package:knit/core/ownership/collection_ownership.dart';
import 'package:knit/features/collection/domain/collection_failure.dart';
import 'package:knit/features/collection/domain/collection_models.dart';
import 'package:knit/features/collection/domain/collection_read_repository.dart';
import 'package:knit/features/collection/domain/link_tile.dart';
import 'package:knit/features/connections/domain/connections_models.dart';
import 'package:knit/sync/sync.dart';
import 'package:result_dart/result_dart.dart';

/// [CollectionReadRepository] over the graph's [SyncStore]: the header via
/// [SyncStore.get], the feed as keyset pages via [SyncStore.feedPage] (§8.7),
/// hydrated with batched attachment, link-count and link-tile reads.
class SyncStoreCollectionReadRepository implements CollectionReadRepository {
  SyncStoreCollectionReadRepository({required AppGraph graph}) : _graph = graph;

  final AppGraph _graph;

  @override
  Future<Result<CollectionData, CollectionFailure>> loadCollection(
    String id, {
    FeedWindow window = const FeedWindow.all(),
  }) async {
    try {
      final store = _graph.store;
      final header = await store.get(EntityType.collection, id);
      if (header == null || header.deleted) {
        return const Failure(CollectionLoadFailure('collection not found'));
      }

      final ownership = CollectionOwnership.of(
        header.createdBy,
        await store.authorPubkey(),
      );
      final (rows, boundary) = await _readWindow(store, id, window);
      // One batched link-count read covers every card *and* the collection
      // itself (§4.4) — no per-card query, however large the window.
      final (cards, counts) = await _hydrate(store, rows, extraCountIds: [id]);

      return Ok(
        CollectionData(
          collectionId: id,
          title: header.content['title'] as String? ?? '',
          description: header.content['description'] as String?,
          coverAttachmentId: header.content['cover_attachment_id'] as String?,
          cards: cards,
          olderBoundary: boundary,
          connectionCount: counts[id] ?? 0,
          ownership: ownership,
          ownerHandle: ownership.canEdit
              ? null
              : await _handleOf(store, header.createdBy),
        ),
      );
    } catch (e, st) {
      return Failure(CollectionLoadFailure(e, st));
    }
  }

  @override
  Future<Result<FeedPage, CollectionFailure>> loadOlderCards(
    String collectionId, {
    required FeedCursor before,
    required int limit,
  }) async {
    try {
      final store = _graph.store;
      final (rows, boundary) = _splitBoundary(
        await store.feedPage(
          collectionId,
          before: _key(before),
          limit: limit + 1,
        ),
        limit,
      );
      final (cards, _) = await _hydrate(store, rows);
      return Ok(FeedPage(cards: cards, olderBoundary: boundary));
    } catch (e, st) {
      return Failure(CollectionLoadFailure(e, st));
    }
  }

  /// Read [window] of [collectionId]'s feed, newest first, plus the key of the
  /// newest card older than it (null ⇒ the window reaches the feed's head).
  /// Bounded windows read one extra row to learn the boundary for free.
  Future<(List<Snapshot>, FeedCursor?)> _readWindow(
    SyncStore store,
    String collectionId,
    FeedWindow window,
  ) async {
    Future<(List<Snapshot>, FeedCursor?)> latest(int limit) async =>
        _splitBoundary(
          await store.feedPage(collectionId, limit: limit + 1),
          limit,
        );

    Future<(List<Snapshot>, FeedCursor?)> from(FeedKey anchor) async {
      final rows = await store.feedPage(collectionId, atOrAfter: anchor);
      final older = await store.feedPage(
        collectionId,
        before: anchor,
        limit: 1,
      );
      return (rows, older.isEmpty ? null : _cursor(older.first));
    }

    switch (window) {
      case AllFeedWindow():
        return (await store.feedPage(collectionId), null);
      case LatestFeedWindow(:final limit):
        return latest(limit);
      case FromFeedWindow(:final cursor):
        return from(_key(cursor));
      case ThroughFeedWindow(:final cardId, :final minLimit):
        final card = await store.get(EntityType.card, cardId);
        if (card == null ||
            card.deleted ||
            card.content['collection_id'] != collectionId) {
          return latest(minLimit);
        }
        final through = await from((position: card.position!, id: card.id));
        // A card near the bottom: a full first page still reveals it.
        return through.$1.length < minLimit ? latest(minLimit) : through;
    }
  }

  /// Split a `limit + 1` newest-first read into the page and the boundary key
  /// (the extra, oldest row — present only when more cards exist).
  static (List<Snapshot>, FeedCursor?) _splitBoundary(
    List<Snapshot> rows,
    int limit,
  ) => rows.length > limit
      ? (rows.sublist(0, limit), _cursor(rows[limit]))
      : (rows, null);

  /// Map newest-first card rows to [FeedCard]s in feed order (oldest → newest),
  /// resolving file/audio metadata and link counts in batched reads. Returns
  /// the counts too, which include [extraCountIds] (e.g. the collection).
  Future<(List<FeedCard>, Map<String, int>)> _hydrate(
    SyncStore store,
    List<Snapshot> rowsNewestFirst, {
    List<String> extraCountIds = const [],
  }) async {
    final rows = rowsNewestFirst.reversed.toList(growable: false);

    // A file (or picked audio) card needs its attachment's name + size to label
    // the chip; resolve the (tiny) metadata records in one read so the feed
    // renders them without a per-card bytes load (unlike image thumbnails).
    final metaIds = <String>{
      for (final card in rows)
        if (_needsMeta(card)) ?card.content['attachment_id'] as String?,
    };
    final meta = {
      for (final att in await store.getMany(EntityType.attachment, metaIds))
        if (!att.deleted) att.id: att,
    };

    // Every link each card takes part in, both directions (§4.4): links-out
    // plus backlinks, so the receiving end also shows it's connected. The sets
    // are disjoint per card, so a single link is never double-counted.
    final counts = await store.linkCounts([
      for (final card in rows) card.id,
      ...extraCountIds,
    ]);

    final tiles = await _linkTiles(store, rows, counts);

    final cards = [
      for (final card in rows)
        _feedCard(
          card,
          meta[card.content['attachment_id']],
          counts[card.id],
          tiles[card.id],
        ),
    ];
    return (cards, counts);
  }

  /// The rich tile of each card in [rows] whose whole purpose is linking to a
  /// live collection or card (§4.2), by card id — batched: one links-out read
  /// for the linked cards, then one summary read for the collection targets
  /// and a few `getMany` reads for the card targets (their rows, collections
  /// and file names). A deleted target gets no tile, so the card keeps the
  /// plain bubble and its broken chip.
  Future<Map<String, LinkTile>> _linkTiles(
    SyncStore store,
    List<Snapshot> rows,
    Map<String, int> counts,
  ) async {
    final linked = [
      for (final card in rows)
        if ((counts[card.id] ?? 0) > 0) card,
    ];
    if (linked.isEmpty) return const {};
    final linksOut = <String, List<CardLinkOut>>{};
    for (final link in await store.linksOutOf([for (final c in linked) c.id])) {
      (linksOut[link.content[LinkSchema.colSourceId] as String] ??= []).add((
        targetKind: ConnectedEntityKind.fromTag(
          link.content[LinkSchema.colTargetType] as String?,
        ),
        targetId: link.content[LinkSchema.colTargetId] as String,
      ));
    }
    final targets = <String, CardLinkOut>{
      for (final card in linked)
        card.id: ?LinkTile.targetOf(
          kind: CardKind.fromTag(card.content['kind'] as String?),
          text: card.content['text'] as String?,
          attachmentIds: CardSchema.attachmentIdsOf(card.content),
          linksOut: linksOut[card.id] ?? const [],
        ),
    };
    if (targets.isEmpty) return const {};
    Iterable<String> idsOf(ConnectedEntityKind kind) => [
      for (final t in targets.values)
        if (t.targetKind == kind) t.targetId,
    ];
    final summaries = {
      for (final s in await store.collectionSummaries(
        idsOf(ConnectedEntityKind.collection),
      ))
        s.collectionId: s,
    };
    final cardTargets = await _cardTargets(
      store,
      idsOf(ConnectedEntityKind.card),
    );
    final tiles = <String, LinkTile>{};
    for (final card in linked) {
      final target = targets[card.id];
      if (target == null) continue;
      final cardText = card.content['text'] as String?;
      switch (target.targetKind) {
        case ConnectedEntityKind.collection:
          if (summaries[target.targetId] case final summary?) {
            tiles[card.id] = CollectionLinkTile.of(
              cardText: cardText,
              collectionId: summary.collectionId,
              title: summary.title,
              cardCount: summary.cardCount,
              coverAttachmentId: summary.coverAttachmentId,
              lastCardKind: summary.lastCard?.kind,
              lastCardText: summary.lastCard?.text,
              lastCardSettled: summary.lastCard?.settled ?? false,
            );
          }
        case ConnectedEntityKind.card:
          if (cardTargets[target.targetId] case (
            final row,
            final collection,
            final fileName,
          )) {
            final kind = CardKind.fromTag(row.content['kind'] as String?);
            tiles[card.id] = CardLinkTile.of(
              cardText: cardText,
              cardId: row.id,
              cardKind: kind.tag,
              collectionId: collection.id,
              collectionTitle:
                  collection.content[CollectionSchema.colTitle] as String? ??
                  '',
              text: row.content['text'] as String?,
              fileName: fileName,
              thumbnailAttachmentId: kind == CardKind.image
                  ? row.content['attachment_id'] as String?
                  : null,
              settled: row.content[CardSchema.colSettledAt] != null,
            );
          }
        case ConnectedEntityKind.unknown:
          break;
      }
    }
    return tiles;
  }

  /// The live cards among [cardIds] that sit in a live collection, by id,
  /// with that collection and (file and audio cards) the attachment's file
  /// name — three batched reads.
  static Future<Map<String, (Snapshot, Snapshot, String?)>> _cardTargets(
    SyncStore store,
    Iterable<String> cardIds,
  ) async {
    final ids = cardIds.toSet();
    if (ids.isEmpty) return const {};
    final cards = [
      for (final c in await store.getMany(EntityType.card, ids))
        if (!c.deleted) c,
    ];
    final collections = {
      for (final c in await store.getMany(EntityType.collection, {
        for (final card in cards) card.content['collection_id'] as String,
      }))
        if (!c.deleted) c.id: c,
    };
    final names = {
      for (final att in await store.getMany(EntityType.attachment, {
        for (final card in cards)
          if (_needsMeta(card)) ?card.content['attachment_id'] as String?,
      }))
        if (!att.deleted)
          att.id: att.content[AttachmentSchema.colName] as String?,
    };
    return {
      for (final card in cards)
        if (collections[card.content['collection_id']] case final collection?)
          card.id: (card, collection, names[card.content['attachment_id']]),
    };
  }

  static bool _needsMeta(Snapshot card) {
    final kind = CardKind.fromTag(card.content['kind'] as String?);
    return kind == CardKind.file || kind == CardKind.audio;
  }

  static FeedCard _feedCard(
    Snapshot card,
    Snapshot? att,
    int? linkCount,
    LinkTile? linkTile,
  ) {
    final kind = CardKind.fromTag(card.content['kind'] as String?);
    final withMeta = att != null && _needsMeta(card);
    return FeedCard(
      id: card.id,
      kind: kind,
      position: card.position!,
      text: card.content['text'] as String?,
      attachmentId: card.content['attachment_id'] as String?,
      moreAttachmentIds: CardSchema.decodeMoreAttachmentIds(
        card.content[CardSchema.colMoreAttachmentIds],
      ),
      fileName: withMeta
          ? att.content[AttachmentSchema.colName] as String?
          : null,
      fileSize: withMeta ? att.content[AttachmentSchema.colSize] as int? : null,
      connectionCount: linkCount ?? 0,
      settledAt: card.content[CardSchema.colSettledAt] as int?,
      emphasizedAt: card.content[CardSchema.colEmphasizedAt] as int?,
      linkTile: linkTile,
    );
  }

  /// `nickname#fingerprint` of [pubkey]; the nickname is blank when its
  /// profile never arrived.
  static Future<String> _handleOf(SyncStore store, String pubkey) async {
    final profile = await store.get(EntityType.profile, pubkey);
    final nickname = profile?.content[ProfileSchema.colNickname] as String?;
    return '${nickname ?? ''}#${await store.signer.fingerprintOf(pubkey)}';
  }

  static FeedCursor _cursor(Snapshot card) =>
      FeedCursor(card.position!, card.id);

  static FeedKey _key(FeedCursor cursor) =>
      (position: cursor.position, id: cursor.id);

  @override
  Future<Result<bool, CollectionFailure>> isAttachmentReferenced(
    String attachmentId,
  ) async {
    try {
      // readAll, not feed: a card in *any* collection counts as a referent.
      final referenced = (await _graph.store.readAll(EntityType.card)).any(
        (c) =>
            !c.deleted &&
            CardSchema.attachmentIdsOf(c.content).contains(attachmentId),
      );
      return Ok(referenced);
    } catch (e, st) {
      return Failure(CollectionLoadFailure(e, st));
    }
  }
}
