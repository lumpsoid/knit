import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:knit/features/collection/presentation/widgets/card_backlinks_badge.dart';
import 'package:knit/features/collection/presentation/widgets/card_link_chips.dart';
import 'package:knit/l10n/app_localizations.dart';

/// The row under a card bubble (§4.2): link chips and the backlinks badge.
void main() {
  Widget host(Widget child, {double width = 400}) => MaterialApp(
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    home: Scaffold(
      body: Align(
        alignment: Alignment.topLeft,
        child: SizedBox(width: width, child: child),
      ),
    ),
  );

  testWidgets('each chip shows its label and follows its tap', (tester) async {
    final taps = <String>[];
    await tester.pumpWidget(
      host(
        CardLinkChips(
          chips: [
            LinkChipView(label: '→ Trips', onTap: () => taps.add('trips')),
            LinkChipView(
              label: '→ unavailable',
              muted: true,
              onTap: () => taps.add('broken'),
            ),
            LinkChipView(label: '+2', onTap: () => taps.add('more')),
          ],
        ),
      ),
    );
    await tester.tap(find.text('→ Trips'));
    await tester.tap(find.text('→ unavailable'));
    await tester.tap(find.text('+2'));
    expect(taps, ['trips', 'broken', 'more']);
  });

  testWidgets('an archived chip carries the archive glyph', (tester) async {
    await tester.pumpWidget(
      host(
        CardLinkChips(
          chips: [LinkChipView(label: '→ Old', archived: true, onTap: () {})],
        ),
      ),
    );
    expect(find.byIcon(Icons.inventory_2_outlined), findsOneWidget);
  });

  testWidgets('long labels ellipsize within a narrow phone row', (
    tester,
  ) async {
    final long = '→ ${'A very long card preview ' * 8}';
    await tester.pumpWidget(
      host(
        CardLinkChips(
          chips: [
            LinkChipView(label: long, onTap: () {}),
            LinkChipView(label: long, onTap: () {}),
          ],
          trailing: CardBacklinksBadge(count: 3, onTap: () {}),
        ),
        width: 160,
      ),
    );
    expect(tester.takeException(), isNull);
    final text = tester.widget<Text>(find.text(long).first);
    expect(text.overflow, TextOverflow.ellipsis);
    expect(tester.getSize(find.byType(CardLinkChips)).width, 160);
  });

  testWidgets('the badge counts backlinks with a ← glyph; a tap opens', (
    tester,
  ) async {
    var opened = 0;
    await tester.pumpWidget(
      host(
        CardLinkChips(
          chips: const [],
          trailing: CardBacklinksBadge(count: 2, onTap: () => opened++),
        ),
      ),
    );
    expect(find.byIcon(Icons.west), findsOneWidget);
    expect(find.text('2'), findsOneWidget);
    expect(find.byTooltip('Linked from 2 places'), findsOneWidget);
    await tester.tap(find.text('2'));
    expect(opened, 1);
  });

  testWidgets('no chip draws a blurred shadow', (tester) async {
    await tester.pumpWidget(
      host(
        CardLinkChips(
          chips: [LinkChipView(label: '→ Trips', onTap: () {})],
        ),
      ),
    );
    for (final box in tester.widgetList<DecoratedBox>(
      find.byType(DecoratedBox),
    )) {
      final decoration = box.decoration;
      if (decoration is BoxDecoration) {
        for (final shadow in decoration.boxShadow ?? const <BoxShadow>[]) {
          expect(shadow.blurRadius, 0);
        }
      }
    }
    for (final material in tester.widgetList<Material>(
      find.descendant(
        of: find.byType(CardLinkChips),
        matching: find.byType(Material),
      ),
    )) {
      expect(material.elevation, 0);
    }
  });
}
