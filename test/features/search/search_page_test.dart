import 'package:flutter/material.dart' hide SearchController;
import 'package:flutter_test/flutter_test.dart';
import 'package:knit/core/recents/recents.dart';
import 'package:knit/features/card_links/domain/card_links_failure.dart';
import 'package:knit/features/card_links/domain/card_links_models.dart';
import 'package:knit/features/card_links/domain/card_links_write_repository.dart';
import 'package:knit/features/card_links/domain/link_targets_read_repository.dart';
import 'package:knit/features/card_links/presentation/card_links_controller.dart';
import 'package:knit/features/collection/presentation/collection_route_args.dart';
import 'package:knit/features/connections/domain/connections_models.dart';
import 'package:knit/features/search/domain/search_failure.dart';
import 'package:knit/features/search/domain/search_filter.dart';
import 'package:knit/features/search/domain/search_models.dart';
import 'package:knit/features/search/domain/search_read_repository.dart';
import 'package:knit/features/search/presentation/search_controller.dart';
import 'package:knit/features/search/presentation/search_page.dart';
import 'package:knit/l10n/app_localizations.dart';
import 'package:result_dart/result_dart.dart';

class _Read implements SearchReadRepository {
  int loads = 0;

  @override
  Future<Result<List<SearchDocument>, SearchFailure>> loadDocuments() async {
    loads++;
    return Ok([
      for (final (id, text, ms, links) in [
        ('soup', 'Soup', 1, {'veg', 'quick'}),
        ('salad', 'Salad', 2, {'veg'}),
        ('steak', 'Steak', 3, {'quick'}),
      ])
        SearchDocument(
          kind: SearchHitKind.card,
          id: id,
          collectionId: 'recipes',
          collectionTitle: 'Recipes',
          texts: [SearchText(SearchField.cardText, text)],
          updatedAtMs: ms,
          cardKind: 'text',
          linksOut: links,
        ),
    ]);
  }
}

class _Targets implements LinkTargetsReadRepository {
  @override
  Future<Result<List<LinkTarget>, CardLinksFailure>> loadCollections() async =>
      const Ok([
        LinkTarget(
          kind: ConnectedEntityKind.collection,
          id: 'veg',
          label: 'Vegetarian',
        ),
        LinkTarget(
          kind: ConnectedEntityKind.collection,
          id: 'quick',
          label: 'Quick',
        ),
      ]);

  @override
  Future<Result<List<LinkTarget>, CardLinksFailure>> loadCards(
    String collectionId,
  ) async => const Ok([]);

  @override
  Future<Result<LinkedTargets, CardLinksFailure>> loadLinkedTargets(
    String cardId,
  ) => throw UnimplementedError();
}

class _UnusedWrite implements CardLinksWriteRepository {
  @override
  dynamic noSuchMethod(Invocation invocation) => throw UnimplementedError();
}

/// The Search page's "Linked to…" filter (§4.1): opened pre-filtered it
/// lists the tag's members at once; the picker adds a target (AND), and a
/// chip's ✕ removes it — all over the one load.
void main() {
  testWidgets('browses a tag at once; the picker and ✕ edit the filter', (
    tester,
  ) async {
    final read = _Read();
    final recents = InMemoryRecentTargetsRepository();
    final controller = SearchController(
      readRepository: read,
      collectionRouteArgs: InMemoryCollectionRouteArgsStore(),
      links: CardLinksController(
        readRepository: _Targets(),
        writeRepository: _UnusedWrite(),
        recentsReadRepository: recents,
        recentsWriteRepository: recents,
      ),
      filter: SearchFilter(
        linkedTo: {
          const SearchLinkTarget(
            kind: SearchHitKind.collection,
            id: 'veg',
            label: 'Vegetarian',
          ),
        },
      ),
    );
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: SearchPage(controller: controller),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('→ Vegetarian'), findsOneWidget);
    expect(find.text('Salad'), findsOneWidget);
    expect(find.text('Soup'), findsOneWidget);
    expect(find.text('Steak'), findsNothing);
    expect(
      tester.getTopLeft(find.text('Salad')).dy,
      lessThan(tester.getTopLeft(find.text('Soup')).dy),
    );

    await tester.tap(find.text('Linked to…'));
    await tester.pumpAndSettle();
    expect(find.text('Chosen'), findsOneWidget);
    await tester.tap(find.text('Choose'));
    await tester.pumpAndSettle();

    expect(find.text('→ Quick'), findsOneWidget);
    expect(find.text('Soup'), findsOneWidget);
    expect(find.text('Salad'), findsNothing);

    await tester.tap(find.byTooltip('Remove from filter').first);
    await tester.pumpAndSettle();
    expect(find.text('→ Vegetarian'), findsNothing);
    expect(find.text('Steak'), findsOneWidget);
    expect(find.text('Soup'), findsOneWidget);
    expect(read.loads, 1);
  });
}
