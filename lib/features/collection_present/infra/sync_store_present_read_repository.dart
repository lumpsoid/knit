import 'package:knit/app/app_graph.dart';
import 'package:knit/features/collection/domain/collection_models.dart';
import 'package:knit/features/collection_present/domain/present_failure.dart';
import 'package:knit/features/collection_present/domain/present_models.dart';
import 'package:knit/features/collection_present/domain/present_read_repository.dart';
import 'package:knit/sync/sync.dart';
import 'package:result_dart/result_dart.dart';

/// [PresentReadRepository] over the graph's [SyncStore]: the header, the whole
/// live feed (§8.7), the audio/file names in one batched read, and each linked
/// card's live links both ways (§4.4) with their far end's label. Broken links
/// (§8.6.1) are left out.
class SyncStorePresentReadRepository implements PresentReadRepository {
  SyncStorePresentReadRepository({required AppGraph graph}) : _graph = graph;

  final AppGraph _graph;

  /// How much of a card's text labels a "See also" chip.
  static const int _labelLength = 60;

  @override
  Future<Result<PresentSource, PresentFailure>> loadSource(
    String collectionId,
  ) async {
    try {
      final store = _graph.store;
      final header = await store.get(EntityType.collection, collectionId);
      if (header == null || header.deleted) {
        return const Failure(PresentLoadFailure('collection not found'));
      }
      final rows = await store.feed(collectionId);

      final meta = {
        for (final att in await store.getMany(EntityType.attachment, {
          for (final card in rows)
            if (_needsMeta(card)) ?card.content['attachment_id'] as String?,
        }))
          if (!att.deleted) att.id: att,
      };

      // Only cards that take part in a link pay for the per-card link reads.
      final counts = await store.linkCounts([for (final c in rows) c.id]);
      final cards = <PresentCard>[];
      for (final row in rows) {
        final linked = (counts[row.id] ?? 0) > 0;
        cards.add(
          _card(
            row,
            meta[row.content['attachment_id']],
            linked ? await _links(store, row.id) : const [],
          ),
        );
      }

      return Ok(
        PresentSource(
          collectionId: collectionId,
          title: header.content['title'] as String? ?? '',
          description: header.content['description'] as String?,
          coverAttachmentId: header.content['cover_attachment_id'] as String?,
          cards: cards,
        ),
      );
    } catch (e, st) {
      return Failure(PresentLoadFailure(e, st));
    }
  }

  /// The live far ends of [cardId]'s links-out, then its backlinks, each once.
  Future<List<PresentLink>> _links(SyncStore store, String cardId) async {
    final links = <PresentLink>[];
    final seen = <String>{};
    Future<void> add(Snapshot link, {required bool outgoing}) async {
      final side = outgoing ? 'target' : 'source';
      final kind = _linkKind(link.content['${side}_type'] as String?);
      final id = link.content['${side}_id'] as String?;
      if (kind == null || id == null || !seen.add(id)) return;
      final other = await store.get(_entityType(kind), id);
      if (other == null || other.deleted) return;
      links.add(PresentLink(kind: kind, id: id, label: _label(kind, other)));
    }

    for (final link in await store.linksOut(cardId)) {
      await add(link, outgoing: true);
    }
    for (final link in await store.backlinks(cardId)) {
      await add(link, outgoing: false);
    }
    return links;
  }

  static PresentCard _card(
    Snapshot row,
    Snapshot? att,
    List<PresentLink> links,
  ) {
    final withMeta = att != null && _needsMeta(row);
    return PresentCard(
      id: row.id,
      kind: CardKind.fromTag(row.content['kind'] as String?),
      text: row.content['text'] as String?,
      attachmentId: row.content['attachment_id'] as String?,
      fileName: withMeta
          ? att.content[AttachmentSchema.colName] as String?
          : null,
      settled: row.content[CardSchema.colSettledAt] != null,
      emphasized: row.content[CardSchema.colEmphasizedAt] != null,
      links: links,
    );
  }

  static bool _needsMeta(Snapshot card) {
    final kind = CardKind.fromTag(card.content['kind'] as String?);
    return kind == CardKind.file || kind == CardKind.audio;
  }

  static PresentLinkKind? _linkKind(String? tag) => switch (tag) {
    'card' => PresentLinkKind.card,
    'collection' => PresentLinkKind.collection,
    _ => null,
  };

  static EntityType _entityType(PresentLinkKind kind) => switch (kind) {
    PresentLinkKind.card => EntityType.card,
    PresentLinkKind.collection => EntityType.collection,
  };

  static String _label(PresentLinkKind kind, Snapshot other) {
    final raw = switch (kind) {
      PresentLinkKind.collection => other.content['title'] as String?,
      PresentLinkKind.card => other.content['text'] as String?,
    };
    final text = (raw ?? '').trim().replaceAll(RegExp(r'\s+'), ' ');
    return text.length > _labelLength
        ? '${text.substring(0, _labelLength)}…'
        : text;
  }
}
