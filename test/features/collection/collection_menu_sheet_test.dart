import 'package:flutter/material.dart' hide SearchController;
import 'package:flutter_test/flutter_test.dart';
import 'package:knit/features/collection/presentation/collection_route_args.dart';
import 'package:knit/features/collection/presentation/collection_scope.dart';
import 'package:knit/features/collection/presentation/widgets/collection_menu_sheet.dart';
import 'package:knit/features/search/domain/search_failure.dart';
import 'package:knit/features/search/domain/search_filter.dart';
import 'package:knit/features/search/domain/search_models.dart';
import 'package:knit/features/search/domain/search_read_repository.dart';
import 'package:knit/features/search/presentation/search_controller.dart';
import 'package:knit/l10n/app_localizations.dart';
import 'package:result_dart/result_dart.dart';

class _NoRead implements SearchReadRepository {
  @override
  Future<Result<List<SearchDocument>, SearchFailure>> loadDocuments() async =>
      const Ok([]);
}

/// The Collection ⋮ sheet's "Find linked cards" (§4.1/§4.2): the entry pops
/// its action, own or imported, and the scope hands the "Linked to" filter to
/// the Search factory.
void main() {
  Future<List<CollectionMenuAction?>> pumpSheet(
    WidgetTester tester, {
    bool canEdit = true,
  }) async {
    final choices = <CollectionMenuAction?>[];
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Builder(
          builder: (context) => TextButton(
            onPressed: () async => choices.add(
              await showModalBottomSheet<CollectionMenuAction>(
                context: context,
                builder: (_) => CollectionMenuSheet(
                  canPresent: true,
                  canReorder: false,
                  canEdit: canEdit,
                ),
              ),
            ),
            child: const Text('open'),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    return choices;
  }

  for (final canEdit in [true, false]) {
    testWidgets('"Find linked cards" pops its action (own: $canEdit)', (
      tester,
    ) async {
      final choices = await pumpSheet(tester, canEdit: canEdit);
      await tester.tap(find.text('Find linked cards'));
      await tester.pumpAndSettle();
      expect(choices.single, CollectionMenuAction.findLinked);
    });
  }

  test('createSearch hands the filter, unscoped, to the factory', () {
    SearchScope? gotScope;
    SearchFilter? gotFilter;
    CollectionScope.setSearchFactory(({scope, filter}) {
      gotScope = scope;
      gotFilter = filter;
      return SearchController(
        readRepository: _NoRead(),
        collectionRouteArgs: InMemoryCollectionRouteArgsStore(),
        scope: scope,
        filter: filter ?? const SearchFilter(),
      );
    });
    const tag = SearchLinkTarget(
      kind: SearchHitKind.collection,
      id: 'veg',
      label: 'Vegetarian',
    );
    final controller = CollectionScope.createSearch(
      filter: SearchFilter(linkedTo: {tag}),
    );
    addTearDown(controller.dispose);

    expect(gotScope, isNull);
    expect(gotFilter!.linkedTo, {tag});
    expect(controller.state.filter.linkedTo, {tag});
  });
}
