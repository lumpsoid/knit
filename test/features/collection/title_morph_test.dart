import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:knit/features/collection/presentation/widgets/title_morph.dart';

/// The name hands over from the card to the bar as it scrolls under it: the
/// card paints it until it starts to leave, the flight paints it from then on.
void main() {
  late TitleMorphLink link;
  late ScrollController scroll;

  setUp(() {
    link = TitleMorphLink();
    scroll = ScrollController()..addListener(link.markMoved);
  });

  tearDown(() {
    scroll.dispose();
    link.dispose();
  });

  Future<void> pump(WidgetTester tester, {bool withSlot = true}) =>
      tester.pumpWidget(
        MaterialApp(
          home: Stack(
            children: [
              Scaffold(
                appBar: AppBar(
                  title: withSlot
                      ? TitleMorphTarget(link: link, child: const Text('Name'))
                      : const Text('2 selected'),
                ),
                body: ListView(
                  controller: scroll,
                  children: [
                    const SizedBox(height: 40),
                    TitleMorphSource(
                      link: link,
                      child: const SizedBox(
                        width: double.infinity,
                        child: Text('Name', style: TextStyle(fontSize: 24)),
                      ),
                    ),
                    const SizedBox(height: 2000),
                  ],
                ),
              ),
              Positioned.fill(
                child: TitleMorphFlight(
                  link: link,
                  title: 'Name',
                  sourceStyle: const TextStyle(fontSize: 24),
                  targetStyle: const TextStyle(fontSize: 20),
                ),
              ),
            ],
          ),
        ),
      );

  RenderObject source(WidgetTester tester) =>
      tester.renderObject(find.byType(TitleMorphSource));
  RenderObject flight(WidgetTester tester) => tester.renderObject(
    find.descendant(
      of: find.byType(TitleMorphFlight),
      matching: find.byType(Stack),
    ),
  );

  testWidgets('the card paints the name until it reaches the bar', (
    tester,
  ) async {
    await pump(tester);
    expect(link.progress, 0);
    expect(source(tester), paints..paragraph());
    expect(flight(tester), paintsNothing);
  });

  testWidgets('mid-flight the flight paints it, the card does not', (
    tester,
  ) async {
    await pump(tester);
    scroll.jumpTo(60);
    await tester.pump();
    expect(link.progress, inExclusiveRange(0, 1));
    expect(source(tester), paintsNothing);
    expect(flight(tester), paints..paragraph());
  });

  testWidgets('scrolled well past, the name is docked', (tester) async {
    await pump(tester);
    scroll.jumpTo(600);
    await tester.pump();
    expect(link.progress, 1);
  });

  testWidgets('with no slot in the bar the card keeps its name', (
    tester,
  ) async {
    await pump(tester, withSlot: false);
    scroll.jumpTo(60);
    await tester.pump();
    expect(link.progress, isNull);
    expect(source(tester), paints..paragraph());
    expect(flight(tester), paintsNothing);
  });
}
