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
  _Read([this.linked = const {}]);

  /// The source card's links, by target id (the ✓ marks).
  final Map<(ConnectedEntityKind, String), String> linked;
  final linkedReads = <String>[];

  @override
  Future<Result<LinkedTargets, CardLinksFailure>> loadLinkedTargets(
    String cardId,
  ) async {
    linkedReads.add(cardId);
    return Ok(LinkedTargets(linked));
  }

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
  Future<Result<LinksAdded, CardLinksFailure>> addLinks({
    required List<String> sourceIds,
    required ConnectedEntityKind targetKind,
    required String targetId,
  }) => throw UnimplementedError();

  @override
  Future<Result<LinksAdded, CardLinksFailure>> addLinksToNewCollection({
    required List<String> sourceIds,
    required String title,
  }) => throw UnimplementedError();

  @override
  Future<Result<String, CardLinksFailure>> addLink({
    required ConnectedEntityKind sourceKind,
    required String sourceId,
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
  Future<List<LinkPickerChoice?>> pumpPicker(
    WidgetTester tester, {
    InMemoryRecentTargetsRepository? recents,
    LinkPick source = const LinkSource(cardId: 'self', collectionId: 'own'),
    _Read? read,
  }) async {
    final store = recents ?? InMemoryRecentTargetsRepository();
    final links = CardLinksController(
      readRepository: read ?? _Read(),
      writeRepository: _UnusedWrite(),
      recentsReadRepository: store,
      recentsWriteRepository: store,
    );
    final picked = <LinkPickerChoice?>[];
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

    expect((picked.single! as LinkTargetPicked).target.id, 'sib');
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
    expect((picked.single! as LinkTargetPicked).target.id, 'other');
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
    expect((picked.single! as LinkTargetPicked).target.id, 'other');
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
    expect(
      (picked.single! as LinkTargetPicked).target.kind,
      ConnectedEntityKind.card,
    );
    expect((picked.single! as LinkTargetPicked).target.id, 'sib');
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
    expect(
      (picked.single! as LinkTargetPicked).target.kind,
      ConnectedEntityKind.collection,
    );
    expect((picked.single! as LinkTargetPicked).target.id, 'other');
  });

  group('✓ toggles', () {
    const linked = {
      (ConnectedEntityKind.collection, 'other'): 'l-other',
      (ConnectedEntityKind.card, 'sib'): 'l-sib',
    };

    testWidgets('a linked collection shows ✓ and unpicks its link', (
      tester,
    ) async {
      final recents = InMemoryRecentTargetsRepository({
        RecentPurpose.link: ['other'],
      });
      final picked = await pumpPicker(
        tester,
        recents: recents,
        read: _Read(linked),
      );

      expect(find.text('Link'), findsNothing);
      expect(find.text('Linked'), findsOneWidget);
      final chip = find.widgetWithText(ActionChip, 'Other');
      expect(
        find.descendant(of: chip, matching: find.byIcon(Icons.check)),
        findsOneWidget,
      );

      await tester.tap(find.text('Linked'));
      await tester.pumpAndSettle();
      final choice = picked.single! as LinkTargetUnpicked;
      expect(choice.target.id, 'other');
      expect(choice.linkId, 'l-other');
    });

    testWidgets('a linked card shows ✓ and unpicks; others still pick', (
      tester,
    ) async {
      final picked = await pumpPicker(tester, read: _Read(linked));

      await tester.tap(find.text('Own'));
      await tester.pumpAndSettle();
      expect(
        find.descendant(
          of: find.widgetWithText(ListTile, 'Sibling'),
          matching: find.byIcon(Icons.check),
        ),
        findsOneWidget,
      );
      await tester.tap(find.text('Sibling'));
      await tester.pumpAndSettle();
      expect((picked.single! as LinkTargetUnpicked).linkId, 'l-sib');
    });

    testWidgets('a new Connection has no source card, so no ✓', (tester) async {
      final read = _Read(linked);
      final picked = await pumpPicker(
        tester,
        read: read,
        source: const NewConnection(collectionId: 'own'),
      );

      expect(read.linkedReads, isEmpty);
      expect(find.text('Linked'), findsNothing);
      await tester.tap(find.text('Link'));
      await tester.pumpAndSettle();
      expect(picked.single, isA<LinkTargetPicked>());
    });
  });

  group('New collection', () {
    testWidgets('grows into the title line and picks the new title', (
      tester,
    ) async {
      final picked = await pumpPicker(tester);

      await tester.tap(find.text('New collection'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), '  Fresh  ');
      await tester.pump();
      await tester.tap(find.byIcon(Icons.arrow_upward));
      await tester.pumpAndSettle();

      expect((picked.single! as LinkToNewCollection).title, 'Fresh');
    });

    testWidgets('a title like a listed collection offers "Link there"', (
      tester,
    ) async {
      final picked = await pumpPicker(tester);

      await tester.tap(find.text('New collection'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), 'other');
      await tester.pumpAndSettle();
      await tester.tap(find.text('Link there'));
      await tester.pumpAndSettle();

      expect((picked.single! as LinkTargetPicked).target.id, 'other');
    });

    testWidgets('never offers the source card\'s own collection', (
      tester,
    ) async {
      final picked = await pumpPicker(tester);

      await tester.tap(find.text('New collection'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), 'own');
      await tester.pumpAndSettle();
      expect(find.text('Link there'), findsNothing);
      await tester.tap(find.byIcon(Icons.arrow_upward));
      await tester.pumpAndSettle();

      expect((picked.single! as LinkToNewCollection).title, 'own');
    });

    testWidgets('dismissing the line picks nothing', (tester) async {
      final picked = await pumpPicker(tester);

      await tester.tap(find.text('New collection'));
      await tester.pumpAndSettle();
      await tester.tapAt(const Offset(10, 10)); // the scrim
      await tester.pumpAndSettle();

      expect(picked.single, isNull);
    });

    testWidgets('"Link from my card…" has no New collection row', (
      tester,
    ) async {
      await pumpPicker(
        tester,
        source: const LinkFromMine(targetCardId: 'theirs'),
      );
      expect(find.text('New collection'), findsNothing);
    });
  });

  group('multi-select Link to…', () {
    const selection = LinkSelection(
      cardIds: ['self', 'sib'],
      collectionId: 'own',
    );

    testWidgets('shows no ✓ and never links to its own collection', (
      tester,
    ) async {
      final read = _Read(const {
        (ConnectedEntityKind.collection, 'other'): 'l-other',
      });
      final picked = await pumpPicker(tester, read: read, source: selection);

      expect(find.text('Link 2 cards to…'), findsOneWidget);
      expect(read.linkedReads, isEmpty);
      expect(find.text('Linked'), findsNothing);
      expect(find.text('Link'), findsOneWidget); // Other only
      await tester.tap(find.text('Link'));
      await tester.pumpAndSettle();
      expect((picked.single! as LinkTargetPicked).target.id, 'other');
    });

    testWidgets('a selected card may be the target of the others', (
      tester,
    ) async {
      final picked = await pumpPicker(tester, source: selection);

      await tester.tap(find.widgetWithText(ListTile, 'Own'));
      await tester.pumpAndSettle();
      expect(find.text('Self'), findsOneWidget);
      await tester.tap(find.text('Self'));
      await tester.pumpAndSettle();
      expect((picked.single! as LinkTargetPicked).target.id, 'self');
    });

    testWidgets('one selected card is not its own target', (tester) async {
      await pumpPicker(
        tester,
        source: const LinkSelection(cardIds: ['self'], collectionId: 'own'),
      );

      await tester.tap(find.widgetWithText(ListTile, 'Own'));
      await tester.pumpAndSettle();
      expect(find.text('Self'), findsNothing);
      expect(find.text('Sibling'), findsOneWidget);
    });
  });
}
