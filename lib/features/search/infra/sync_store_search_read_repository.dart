import 'package:knit/app/app_graph.dart';
import 'package:knit/features/search/domain/search_failure.dart';
import 'package:knit/features/search/domain/search_models.dart';
import 'package:knit/features/search/domain/search_read_repository.dart';
import 'package:knit/sync/sync.dart';
import 'package:result_dart/result_dart.dart';

/// [SearchReadRepository] over the graph's [SyncStore]: flattens every live
/// collection (title, description) and every live card of a live collection
/// (text, attachment file name) into a [SearchDocument]. A live link's label is
/// searchable on its *source* entity — the card or collection it was made from
/// — and its target is among the source's [SearchDocument.linksOut]; all links
/// come from one batched read. Tombstoned rows never surface; archived ones
/// do, flagged (§3.4).
class SyncStoreSearchReadRepository implements SearchReadRepository {
  SyncStoreSearchReadRepository({required AppGraph graph}) : _graph = graph;

  final AppGraph _graph;

  @override
  Future<Result<List<SearchDocument>, SearchFailure>> loadDocuments() async {
    try {
      final store = _graph.store;
      final collections = {
        for (final c in await store.readAll(EntityType.collection))
          if (!c.deleted) c.id: c,
      };
      final fileNames = {
        for (final a in await store.readAll(EntityType.attachment))
          if (!a.deleted) a.id: a.content[AttachmentSchema.colName] as String?,
      };
      final cards = [
        for (final card in await store.readAll(EntityType.card))
          if (!card.deleted &&
              collections.containsKey(card.content['collection_id']))
            card,
      ];
      // One batched read of every document's live links out, one per pair
      // (§6.4): their labels are searchable, their targets feed "Linked to…".
      final labelsBySource = <String, List<String>>{};
      final linksOut = <String, Set<String>>{};
      for (final link in await store.linksOutOf([
        ...collections.keys,
        for (final card in cards) card.id,
      ])) {
        final sourceId = link.content['source_id'] as String;
        (linksOut[sourceId] ??= {}).add(link.content['target_id'] as String);
        final label = link.content['label'] as String?;
        if (label == null || label.trim().isEmpty) continue;
        (labelsBySource[sourceId] ??= []).add(label);
      }

      List<SearchText> labelsOf(String id) => [
        for (final label in labelsBySource[id] ?? const <String>[])
          SearchText(SearchField.linkLabel, label),
      ];

      final documents = <SearchDocument>[];
      for (final col in collections.values) {
        final title = col.content['title'] as String? ?? '';
        final description = col.content['description'] as String?;
        documents.add(
          SearchDocument(
            kind: SearchHitKind.collection,
            id: col.id,
            collectionId: col.id,
            collectionTitle: title,
            texts: [
              if (title.isNotEmpty)
                SearchText(SearchField.collectionTitle, title),
              if (description != null && description.isNotEmpty)
                SearchText(SearchField.description, description),
              ...labelsOf(col.id),
            ],
            updatedAtMs: col.hlc.ms,
            archived: _isArchived(col),
            linksOut: linksOut[col.id] ?? const {},
          ),
        );
      }

      for (final card in cards) {
        final col = collections[card.content['collection_id'] as String]!;
        final text = card.content['text'] as String?;
        final fileName = fileNames[card.content['attachment_id'] as String?];
        documents.add(
          SearchDocument(
            kind: SearchHitKind.card,
            id: card.id,
            collectionId: col.id,
            collectionTitle: col.content['title'] as String? ?? '',
            texts: [
              if (text != null && text.isNotEmpty)
                SearchText(SearchField.cardText, text),
              if (fileName != null && fileName.isNotEmpty)
                SearchText(SearchField.fileName, fileName),
              ...labelsOf(card.id),
            ],
            updatedAtMs: card.hlc.ms,
            cardKind: card.content['kind'] as String?,
            settled: card.content[CardSchema.colSettledAt] != null,
            archived: _isArchived(col),
            linksOut: linksOut[card.id] ?? const {},
          ),
        );
      }
      return Ok(documents);
    } catch (e, st) {
      return Failure(SearchLoadFailure(e, st));
    }
  }

  static bool _isArchived(Snapshot collection) =>
      collection.content[CollectionSchema.colArchivedAt] != null;
}
