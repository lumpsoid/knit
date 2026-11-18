import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:knit/features/timeline/presentation/timeline_action.dart';
import 'package:knit/features/timeline/presentation/widgets/timeline_collection_actions.dart';
import 'package:knit/l10n/app_localizations.dart';

/// Hosts a button that opens the sheet for a row titled "Trips" and reports the
/// chosen action to [onResult] (null when dismissed).
Future<void> _openSheet(
  WidgetTester tester, {
  required bool isArchived,
  required ValueSetter<TimelineCollectionAction?> onResult,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(
        body: Builder(
          builder: (context) => TextButton(
            onPressed: () async {
              onResult(
                await showTimelineCollectionActions(
                  context,
                  title: 'Trips',
                  isPinned: false,
                  isArchived: isArchived,
                ),
              );
            },
            child: const Text('open'),
          ),
        ),
      ),
    ),
  );
  await tester.tap(find.text('open'));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('Home offers Reorder', (tester) async {
    TimelineCollectionAction? result;
    await _openSheet(
      tester,
      isArchived: false,
      onResult: (action) => result = action,
    );

    expect(find.text('Reorder'), findsOneWidget);
    await tester.tap(find.text('Reorder'));
    await tester.pumpAndSettle();
    expect(result, TimelineCollectionAction.reorder);
  });

  testWidgets('the Archive page offers no Reorder', (tester) async {
    await _openSheet(tester, isArchived: true, onResult: (_) {});

    // Positive control: the sheet is open, so its Archive-side row is there.
    expect(find.text('Unarchive'), findsOneWidget);
    expect(find.text('Reorder'), findsNothing);
  });

  test('Reorder dispatches ReorderStarted', () {
    expect(
      TimelineCollectionAction.reorder.toAction('c1'),
      isA<ReorderStarted>(),
    );
  });
}
