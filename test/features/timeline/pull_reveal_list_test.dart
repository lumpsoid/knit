import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:knit/features/timeline/presentation/widgets/pull_reveal_list.dart';

/// The Home pull-down that reveals the Archive row (§3.4): hidden at first, a
/// short pull reveals it and it stays, scrolling it away hides it again, and a
/// long pull still refreshes.
void main() {
  const headerHeight = 64.0;
  final header = find.text('Archive');

  Future<int Function()> pump(
    WidgetTester tester, {
    bool hasHeader = true,
    bool alwaysShowHeader = false,
    int rows = 40,
  }) async {
    var refreshes = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: PullRevealList(
            header: hasHeader
                ? const SizedBox(height: headerHeight, child: Text('Archive'))
                : null,
            headerHeight: headerHeight,
            alwaysShowHeader: alwaysShowHeader,
            onRefresh: () async => refreshes++,
            children: [
              for (var i = 0; i < rows; i++)
                SizedBox(height: 56, child: Text('row $i')),
            ],
          ),
        ),
      ),
    );
    return () => refreshes;
  }

  testWidgets('the header is hidden until pulled', (tester) async {
    await pump(tester);
    expect(header, findsNothing);
    expect(find.text('row 0'), findsOneWidget);
  });

  testWidgets('a short pull reveals the header without refreshing', (
    tester,
  ) async {
    final refreshes = await pump(tester);
    await tester.drag(find.text('row 0'), const Offset(0, 80));
    await tester.pumpAndSettle();

    expect(header, findsOneWidget);
    expect(refreshes(), 0);
    // It sits above the first row.
    expect(
      tester.getTopLeft(header).dy,
      lessThan(tester.getTopLeft(find.text('row 0')).dy),
    );
  });

  testWidgets('a long pull reveals the header and refreshes', (tester) async {
    final refreshes = await pump(tester);
    await tester.fling(find.text('row 0'), const Offset(0, 400), 1000);
    await tester.pumpAndSettle();

    expect(header, findsOneWidget);
    expect(refreshes(), 1);
  });

  testWidgets('scrolling the header out of view hides it in place', (
    tester,
  ) async {
    await pump(tester);
    await tester.drag(find.text('row 0'), const Offset(0, 80));
    await tester.pumpAndSettle();
    expect(header, findsOneWidget);

    await tester.drag(find.text('row 3'), const Offset(0, -300));
    // The frame that lays out the scroll still holds the (offscreen) header…
    await tester.pump();
    expect(find.text('Archive', skipOffstage: false), findsOneWidget);
    final rowTop = tester.getTopLeft(find.text('row 8')).dy;
    // …the next drops it, and the rows haven't moved.
    await tester.pumpAndSettle();
    expect(header, findsNothing);
    expect(tester.getTopLeft(find.text('row 8')).dy, rowTop);
  });

  testWidgets('a mouse wheel up at the top reveals the header', (tester) async {
    await pump(tester);
    final pointer = TestPointer(1, PointerDeviceKind.mouse);
    await tester.sendEventToBinding(
      pointer.hover(tester.getCenter(find.text('row 0'))),
    );
    await tester.sendEventToBinding(pointer.scroll(const Offset(0, -40)));
    await tester.pumpAndSettle();
    expect(header, findsOneWidget);
  });

  testWidgets('no header → a pull only refreshes', (tester) async {
    await pump(tester, hasHeader: false);
    await tester.drag(find.text('row 0'), const Offset(0, 80));
    await tester.pumpAndSettle();
    expect(header, findsNothing);
  });

  testWidgets('alwaysShowHeader shows it without a pull', (tester) async {
    await pump(tester, alwaysShowHeader: true, rows: 0);
    await tester.pumpAndSettle();
    expect(header, findsOneWidget);
  });
}
