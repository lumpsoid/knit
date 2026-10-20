import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:knit/features/collection/presentation/widgets/selection_action_bar.dart';
import 'package:knit/l10n/app_localizations.dart';

/// The multi-select bar fits a narrow phone even with the longest (Russian)
/// labels: Move ellipsizes instead of running off the screen.
void main() {
  for (final locale in AppLocalizations.supportedLocales) {
    testWidgets('fits 320px wide in ${locale.languageCode}', (tester) async {
      tester.view.physicalSize = const Size(320, 640);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(
        MaterialApp(
          locale: locale,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            bottomNavigationBar: SelectionActionBar(
              canSelectAll: true,
              onSelectAll: () {},
              onUnselectAll: () {},
              allSettled: false,
              onSettle: () {},
              allEmphasized: false,
              onEmphasize: () {},
              onMove: () {},
              onDelete: () {},
            ),
          ),
        ),
      );

      expect(tester.takeException(), isNull);
      final move = tester.getRect(find.byType(FilledButton));
      expect(move.right, lessThanOrEqualTo(320));
    });
  }
}
