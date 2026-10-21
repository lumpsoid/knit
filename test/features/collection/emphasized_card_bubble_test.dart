import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:knit/core/emphasized/emphasized_palette.dart';
import 'package:knit/features/collection/domain/collection_models.dart';
import 'package:knit/features/collection/presentation/widgets/card_bubble.dart';
import 'package:knit/l10n/app_localizations.dart';

/// An emphasized card (§3.3) gets a bright frame and a halo; emphasizing
/// animates them in.
void main() {
  Widget bubble({required bool emphasized}) => MaterialApp(
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    home: Scaffold(
      body: CardBubble(
        cardId: '0192f1a2-3b4c-7def-8123-00000000000a',
        kind: CardKind.text,
        text: 'Grind finer if the shot runs too fast.',
        fileName: null,
        fileSize: null,
        images: const [],
        emphasized: emphasized,
        onTap: () {},
      ),
    ),
  );

  Color? frameColor(WidgetTester tester) {
    for (final box in tester.widgetList<DecoratedBox>(
      find.byType(DecoratedBox),
    )) {
      final border = (box.decoration as BoxDecoration?)?.border;
      if (border is Border) return border.top.color;
    }
    return null;
  }

  testWidgets('a live card has no frame', (tester) async {
    await tester.pumpWidget(bubble(emphasized: false));
    expect(frameColor(tester), isNull);
  });

  testWidgets('an emphasized card shows its frame in full', (tester) async {
    await tester.pumpWidget(bubble(emphasized: true));
    expect(frameColor(tester), EmphasizedPalette.frame(Brightness.light));
    expect(find.bySemanticsLabel(RegExp('^Emphasized')), findsOneWidget);
  });

  testWidgets('emphasizing fades the frame in', (tester) async {
    await tester.pumpWidget(bubble(emphasized: false));
    await tester.pumpWidget(bubble(emphasized: true));
    await tester.pump(const Duration(milliseconds: 100));
    expect(frameColor(tester)!.a, inExclusiveRange(0, 1));
    await tester.pumpAndSettle();
    expect(frameColor(tester)!.a, 1);
  });
}
