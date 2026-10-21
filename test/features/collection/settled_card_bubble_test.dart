import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:knit/features/collection/domain/collection_models.dart';
import 'package:knit/features/collection/presentation/widgets/card_bubble.dart';
import 'package:knit/features/collection/presentation/widgets/settled_roots.dart';
import 'package:knit/l10n/app_localizations.dart';

/// A settled card (§3.3) draws its roots and fades; settling animates them in.
void main() {
  Widget bubble({required bool settled}) => MaterialApp(
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
        settled: settled,
        onTap: () {},
      ),
    ),
  );

  SettledRootsPainter? rootsPainter(WidgetTester tester) {
    for (final paint in tester.widgetList<CustomPaint>(
      find.byType(CustomPaint),
    )) {
      if (paint.painter is SettledRootsPainter) {
        return paint.painter! as SettledRootsPainter;
      }
    }
    return null;
  }

  testWidgets('a live card has no roots', (tester) async {
    await tester.pumpWidget(bubble(settled: false));
    expect(rootsPainter(tester), isNull);
    expect(find.byType(ColorFiltered), findsNothing);
  });

  testWidgets('a card that is already settled shows its roots in full', (
    tester,
  ) async {
    await tester.pumpWidget(bubble(settled: true));
    expect(rootsPainter(tester)?.progress, 1);
    expect(find.bySemanticsLabel(RegExp('^Settled')), findsOneWidget);
    expect(find.byType(ColorFiltered), findsOneWidget);
  });

  testWidgets('settling grows the roots', (tester) async {
    await tester.pumpWidget(bubble(settled: false));
    await tester.pumpWidget(bubble(settled: true));
    await tester.pump(const Duration(milliseconds: 200));
    final midway = rootsPainter(tester)!.progress;
    expect(midway, inExclusiveRange(0, 1));
    await tester.pumpAndSettle();
    expect(rootsPainter(tester)!.progress, 1);
  });

  test('the same card always grows the same roots', () {
    final recorder1 = PictureRecorder();
    final recorder2 = PictureRecorder();
    final painter = SettledRootsPainter(
      seed: 'card-1',
      progress: 1,
      color: const Color(0x33000000),
    );
    painter.paint(Canvas(recorder1), const Size(240, 60));
    painter.paint(Canvas(recorder2), const Size(240, 60));
    expect(
      painter.shouldRepaint(
        SettledRootsPainter(
          seed: 'card-1',
          progress: 1,
          color: const Color(0x33000000),
        ),
      ),
      isFalse,
    );
    recorder1.endRecording();
    recorder2.endRecording();
  });
}
