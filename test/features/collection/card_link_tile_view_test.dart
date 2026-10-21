import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:knit/core/settled/settled_palette.dart';
import 'package:knit/features/collection/presentation/widgets/card_link_tile_view.dart';
import 'package:knit/features/collection/presentation/widgets/collection_link_tile_view.dart';
import 'package:knit/l10n/app_localizations.dart';

/// A card-link card's tile in the feed (§4.2).
void main() {
  Widget host(Widget child) => MaterialApp(
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    home: Scaffold(body: child),
  );

  Widget tile({
    String collectionTitle = 'Trips',
    bool settled = false,
    String? caption,
    VoidCallback? onTap,
  }) => host(
    CardLinkTileView(
      preview: 'Lisbon in May',
      collectionTitle: collectionTitle,
      settled: settled,
      thumbnailBytes: null,
      caption: caption,
      onTap: onTap ?? () {},
    ),
  );

  testWidgets('shows the preview and its collection; a tap opens it', (
    tester,
  ) async {
    var opened = 0;
    await tester.pumpWidget(tile(onTap: () => opened++));
    expect(find.text('Lisbon in May'), findsOneWidget);
    expect(find.text('in Trips'), findsOneWidget);
    // No image: the note glyph stands in, unlike a collection's folder.
    expect(find.byIcon(Icons.sticky_note_2_outlined), findsOneWidget);
    expect(find.byIcon(Icons.folder_outlined), findsNothing);
    await tester.tap(find.text('Lisbon in May'));
    expect(opened, 1);
  });

  testWidgets('an untitled collection reads as untitled', (tester) async {
    await tester.pumpWidget(tile(collectionTitle: '  '));
    expect(find.text('in Untitled'), findsOneWidget);
  });

  testWidgets('a settled target is muted', (tester) async {
    await tester.pumpWidget(tile(settled: true));
    final context = tester.element(find.text('Lisbon in May'));
    final text = tester.widget<Text>(find.text('Lisbon in May'));
    expect(
      text.style?.color,
      SettledPalette.previewText(Theme.of(context).colorScheme),
    );
  });

  testWidgets('shares the collection tile\'s ring', (tester) async {
    await tester.pumpWidget(tile(caption: 'Where we met'));
    final cardRing = tester.widget<DecoratedBox>(
      find
          .descendant(
            of: find.byType(CardLinkTileView),
            matching: find.byType(DecoratedBox),
          )
          .first,
    );
    await tester.pumpWidget(
      host(
        CollectionLinkTileView(
          title: 'Trips',
          cardCount: 1,
          preview: 'x',
          coverBytes: null,
          onTap: () {},
        ),
      ),
    );
    final collectionRing = tester.widget<DecoratedBox>(
      find
          .descendant(
            of: find.byType(CollectionLinkTileView),
            matching: find.byType(DecoratedBox),
          )
          .first,
    );
    expect(cardRing.decoration, collectionRing.decoration);
  });
}
