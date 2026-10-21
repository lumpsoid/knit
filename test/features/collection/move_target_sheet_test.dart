import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:knit/features/collection/domain/collection_models.dart';
import 'package:knit/features/collection/presentation/collection_state.dart';
import 'package:knit/features/collection/presentation/widgets/move_target_sheet.dart';
import 'package:knit/l10n/app_localizations.dart';

/// The move picker's "Recent" row (§4.2): shown only when there are recents,
/// and a chip moves there like the target's own row.
void main() {
  const a = MoveTarget(collectionId: 'a', title: 'Alpha');
  const b = MoveTarget(collectionId: 'b', title: 'Beta');

  Future<List<MoveSheetChoice?>> pumpSheet(
    WidgetTester tester, {
    required List<MoveTarget> recents,
  }) async {
    final choices = <MoveSheetChoice?>[];
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Builder(
          builder: (context) => TextButton(
            onPressed: () async => choices.add(
              await showModalBottomSheet<MoveSheetChoice>(
                context: context,
                builder: (_) => MoveTargetSheet(
                  status: MoveTargetsStatus.ready,
                  targets: const [a, b],
                  recents: recents,
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

  testWidgets('no recents, no row', (tester) async {
    await pumpSheet(tester, recents: const []);
    expect(find.text('Recent'), findsNothing);
    expect(find.byType(ActionChip), findsNothing);
  });

  testWidgets('a recent chip moves there', (tester) async {
    final choices = await pumpSheet(tester, recents: const [b]);
    expect(find.text('Recent'), findsOneWidget);
    await tester.tap(find.widgetWithText(ActionChip, 'Beta'));
    await tester.pumpAndSettle();
    expect((choices.single! as MoveSheetTarget).target, b);
  });
}
