import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:knit/core/recents/recents.dart';
import 'package:knit/features/card_links/domain/card_links_failure.dart';
import 'package:knit/features/card_links/domain/card_links_models.dart';
import 'package:knit/features/card_links/domain/card_links_write_repository.dart';
import 'package:knit/features/card_links/domain/link_targets_read_repository.dart';
import 'package:knit/features/card_links/presentation/card_links_controller.dart';
import 'package:knit/features/card_links/presentation/link_picker_sheet.dart';
import 'package:knit/features/connections/domain/connections_models.dart';
import 'package:knit/l10n/app_localizations.dart';
import 'package:result_dart/result_dart.dart';

class _Read implements LinkTargetsReadRepository {
  @override
  Future<Result<List<LinkTarget>, CardLinksFailure>> loadCollections() async =>
      const Ok([
        LinkTarget(
          kind: ConnectedEntityKind.collection,
          id: 'own',
          label: 'Own',
        ),
        LinkTarget(
          kind: ConnectedEntityKind.collection,
          id: 'other',
          label: 'Other',
        ),
      ]);

  @override
  Future<Result<List<LinkTarget>, CardLinksFailure>> loadCards(
    String collectionId,
  ) async => const Ok([
    LinkTarget(kind: ConnectedEntityKind.card, id: 'self', label: 'Self'),
    LinkTarget(kind: ConnectedEntityKind.card, id: 'sib', label: 'Sibling'),
  ]);
}

class _UnusedWrite implements CardLinksWriteRepository {
  @override
  Future<Result<String, CardLinksFailure>> addLink({
    required String sourceCardId,
    required ConnectedEntityKind targetKind,
    required String targetId,
  }) => throw UnimplementedError();

  @override
  Future<Result<String, CardLinksFailure>> removeLink(String linkId) =>
      throw UnimplementedError();
}

void main() {
  /// Pump a button that opens the picker for the card 'self' of 'own', and
  /// record what it pops into the returned list.
  Future<List<LinkTarget?>> pumpPicker(
    WidgetTester tester, {
    InMemoryRecentTargetsRepository? recents,
    LinkPick source = const LinkSource(cardId: 'self', collectionId: 'own'),
  }) async {
    final store = recents ?? InMemoryRecentTargetsRepository();
    final links = CardLinksController(
      readRepository: _Read(),
      writeRepository: _UnusedWrite(),
      recentsReadRepository: store,
      recentsWriteRepository: store,
    );
    final picked = <LinkTarget?>[];
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: const [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        supportedLocales: AppLocalizations.supportedLocales,
        home: Builder(
          builder: (context) => TextButton(
            onPressed: () async => picked.add(
              await LinkPickerSheet.show(context, links: links, source: source),
            ),
            child: const Text('open'),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    return picked;
  }

  testWidgets('drills in, hides the source card, and pops the pick', (
    tester,
  ) async {
    final picked = await pumpPicker(tester);

    // Only the other collection offers a direct link; no recents, no row.
    expect(find.text('Link'), findsOneWidget);
    expect(find.text('Recent'), findsNothing);

    await tester.tap(find.text('Own'));
    await tester.pumpAndSettle();
    expect(find.text('Self'), findsNothing);
    await tester.tap(find.text('Sibling'));
    await tester.pumpAndSettle();

    expect(picked.single?.id, 'sib');
  });

  testWidgets('the Recent row skips the own collection and links on tap', (
    tester,
  ) async {
    final recents = InMemoryRecentTargetsRepository({
      RecentPurpose.link: ['own', 'other'],
    });
    final picked = await pumpPicker(tester, recents: recents);

    expect(find.text('Recent'), findsOneWidget);
    final chip = find.widgetWithText(ActionChip, 'Other');
    expect(chip, findsOneWidget);
    expect(find.widgetWithText(ActionChip, 'Own'), findsNothing);

    await tester.tap(chip);
    await tester.pumpAndSettle();
    expect(picked.single?.id, 'other');
  });

  testWidgets('a new Connection picks a collection, never its own', (
    tester,
  ) async {
    final recents = InMemoryRecentTargetsRepository({
      RecentPurpose.link: ['own', 'other'],
    });
    final picked = await pumpPicker(
      tester,
      recents: recents,
      source: const NewConnection(collectionId: 'own'),
    );

    expect(find.text('Connect to a collection or card'), findsOneWidget);
    // Its own collection is listed to drill into, but offers no Link.
    expect(find.widgetWithText(ListTile, 'Own'), findsOneWidget);
    expect(find.text('Link'), findsOneWidget);
    expect(find.widgetWithText(ActionChip, 'Own'), findsNothing);
    expect(find.widgetWithText(ActionChip, 'Other'), findsOneWidget);

    await tester.tap(find.text('Link'));
    await tester.pumpAndSettle();
    expect(picked.single?.id, 'other');
  });

  testWidgets('a new Connection drills in to pick any card, siblings too', (
    tester,
  ) async {
    final picked = await pumpPicker(
      tester,
      source: const NewConnection(collectionId: 'own'),
    );

    await tester.tap(find.widgetWithText(ListTile, 'Own'));
    await tester.pumpAndSettle();
    // No "Link to Own" row: the card can't point at its own collection.
    expect(find.textContaining('Link to'), findsNothing);
    expect(find.text('Self'), findsOneWidget);
    await tester.tap(find.text('Sibling'));
    await tester.pumpAndSettle();
    expect(picked.single?.kind, ConnectedEntityKind.card);
    expect(picked.single?.id, 'sib');
  });

  testWidgets('a new Connection drills into another collection too', (
    tester,
  ) async {
    final picked = await pumpPicker(
      tester,
      source: const NewConnection(collectionId: 'own'),
    );

    await tester.tap(find.widgetWithText(ListTile, 'Other'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Link to "Other"'));
    await tester.pumpAndSettle();
    expect(picked.single?.kind, ConnectedEntityKind.collection);
    expect(picked.single?.id, 'other');
  });
}
