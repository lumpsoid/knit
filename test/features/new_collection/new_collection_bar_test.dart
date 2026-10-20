import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:knit/features/new_collection/new_collection.dart';
import 'package:knit/l10n/app_localizations.dart';

/// The inline new-collection line (§4.1): sending a title creates, an empty
/// send or a tap outside creates nothing, and a title like an existing
/// collection offers that one instead.
void main() {
  const existing = [
    CollectionTitle(collectionId: 'c1', title: 'Espresso dialing-in'),
  ];

  Future<NewCollectionChoice? Function()> open(WidgetTester tester) async {
    NewCollectionChoice? choice;
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Builder(
          builder: (context) => Scaffold(
            body: Center(
              child: TextButton(
                onPressed: () async {
                  choice = await showNewCollectionBar(
                    context,
                    origin: const Rect.fromLTWH(300, 500, 80, 56),
                    existing: existing,
                    existingActionLabel: 'Open',
                  );
                },
                child: const Text('new'),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('new'));
    await tester.pumpAndSettle();
    return () => choice;
  }

  testWidgets('sending a title creates it, trimmed', (tester) async {
    final choice = await open(tester);
    await tester.enterText(find.byType(TextField), '  Trip to Rome ');
    await tester.pump();
    await tester.tap(find.byIcon(Icons.arrow_upward));
    await tester.pumpAndSettle();

    expect(find.byType(TextField), findsNothing);
    expect(choice(), isA<NewCollectionCreate>());
    expect((choice()! as NewCollectionCreate).title, 'Trip to Rome');
  });

  testWidgets('the send arrow is off until there is a title', (tester) async {
    await open(tester);
    final send = find.widgetWithIcon(IconButton, Icons.arrow_upward);
    expect(tester.widget<IconButton>(send).onPressed, isNull);

    await tester.enterText(find.byType(TextField), 'x');
    await tester.pump();
    expect(tester.widget<IconButton>(send).onPressed, isNotNull);
  });

  testWidgets('submitting an empty title closes without a choice', (
    tester,
  ) async {
    final choice = await open(tester);
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pumpAndSettle();

    expect(find.byType(TextField), findsNothing);
    expect(choice(), isNull);
  });

  testWidgets('a tap outside closes without a choice', (tester) async {
    final choice = await open(tester);
    await tester.tapAt(const Offset(20, 20));
    await tester.pumpAndSettle();

    expect(find.byType(TextField), findsNothing);
    expect(choice(), isNull);
  });

  testWidgets('a title like an existing collection offers it', (tester) async {
    final choice = await open(tester);
    expect(find.text('Open'), findsNothing);

    await tester.enterText(find.byType(TextField), 'espresso');
    await tester.pumpAndSettle();
    expect(
      find.textContaining('Espresso dialing-in', findRichText: true),
      findsOneWidget,
    );

    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();
    expect(choice(), isA<NewCollectionUseExisting>());
    expect((choice()! as NewCollectionUseExisting).collectionId, 'c1');
  });
}
