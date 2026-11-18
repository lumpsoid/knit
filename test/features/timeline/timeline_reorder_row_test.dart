import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:knit/features/timeline/presentation/widgets/timeline_reorder_row.dart';
import 'package:knit/l10n/app_localizations.dart';

TimelineReorderRow _row(String id, String title, int index) =>
    TimelineReorderRow(
      key: ValueKey(id),
      collectionId: id,
      title: title,
      coverBytes: null,
      index: index,
    );

Widget _host(List<Widget> rows) => MaterialApp(
  localizationsDelegates: AppLocalizations.localizationsDelegates,
  supportedLocales: AppLocalizations.supportedLocales,
  home: Scaffold(
    body: ReorderableListView(onReorderItem: (_, _) {}, children: rows),
  ),
);

Finder _gripIn(Finder row) => find.descendant(
  of: row,
  matching: find.byType(ReorderableDragStartListener),
);

void main() {
  testWidgets('shows the title and a drag grip', (tester) async {
    await tester.pumpWidget(_host([_row('a', 'Trips', 0)]));

    expect(find.text('Trips'), findsOneWidget);
    expect(find.byIcon(Icons.drag_indicator), findsOneWidget);
    final grip = tester.widget<ReorderableDragStartListener>(
      _gripIn(find.byType(TimelineReorderRow)),
    );
    expect(grip.index, 0);
  });

  testWidgets('a blank title shows as untitled', (tester) async {
    await tester.pumpWidget(_host([_row('a', '  ', 0)]));

    expect(find.text('Untitled'), findsOneWidget);
  });

  testWidgets('the avatar letters the title without a cover', (tester) async {
    await tester.pumpWidget(_host([_row('a', 'Trips', 0)]));

    expect(find.text('T'), findsOneWidget);
    expect(find.byType(CircleAvatar), findsOneWidget);
  });

  testWidgets('the grip carries the row index', (tester) async {
    await tester.pumpWidget(_host([_row('a', 'One', 0), _row('b', 'Two', 1)]));

    final row = find.ancestor(
      of: find.text('Two'),
      matching: find.byType(TimelineReorderRow),
    );
    final grip = tester.widget<ReorderableDragStartListener>(_gripIn(row));
    expect(grip.index, 1);
  });
}
