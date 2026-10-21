import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:knit/features/collection/presentation/widgets/add_block_sheet.dart';
import 'package:knit/l10n/app_localizations.dart';

/// The "+" sheet (§4.2): a Connection block, no URL link block.
void main() {
  testWidgets('offers Connection instead of a URL link, and pops it', (
    tester,
  ) async {
    final picked = <AddBlock?>[];
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
              await showModalBottomSheet<AddBlock>(
                context: context,
                builder: (_) => const AddBlockSheet(),
              ),
            ),
            child: const Text('open'),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    expect(find.text('Link'), findsNothing);
    expect(find.text('Link to another collection'), findsOneWidget);
    await tester.tap(find.text('Connection'));
    await tester.pumpAndSettle();
    expect(picked.single, AddBlock.connection);
  });
}
