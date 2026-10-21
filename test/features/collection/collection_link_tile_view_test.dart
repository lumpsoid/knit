import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:knit/features/collection/presentation/widgets/collection_link_tile_view.dart';
import 'package:knit/l10n/app_localizations.dart';

/// A collection-link card's tile in the feed (§4.2).
void main() {
  Widget tile({String? caption, required VoidCallback onTap}) => MaterialApp(
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    home: Scaffold(
      body: CollectionLinkTileView(
        title: 'Trips',
        cardCount: 3,
        preview: 'Lisbon',
        coverBytes: null,
        caption: caption,
        onTap: onTap,
      ),
    ),
  );

  testWidgets('shows the title, count and newest card; a tap opens it', (
    tester,
  ) async {
    var opened = 0;
    await tester.pumpWidget(tile(onTap: () => opened++));
    expect(find.text('Trips'), findsOneWidget);
    expect(find.text('3 cards'), findsOneWidget);
    expect(find.text('Lisbon'), findsOneWidget);
    // No cover: the folder glyph stands in.
    expect(find.byIcon(Icons.folder_outlined), findsOneWidget);
    await tester.tap(find.text('Trips'));
    expect(opened, 1);
  });

  testWidgets('a caption sits above the tile', (tester) async {
    await tester.pumpWidget(tile(caption: 'Next summer', onTap: () {}));
    final caption = tester.getTopLeft(find.text('Next summer'));
    expect(caption.dy, lessThan(tester.getTopLeft(find.text('Trips')).dy));
  });
}
