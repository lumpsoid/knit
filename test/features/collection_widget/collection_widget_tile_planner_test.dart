import 'package:flutter_test/flutter_test.dart';
import 'package:knit/features/collection_widget/domain/domain.dart';

void main() {
  const planner = CollectionWidgetTilePlanner();
  const bindings = [
    CollectionWidgetBinding(widgetId: 1, collectionId: 'a'),
    CollectionWidgetBinding(widgetId: 2, collectionId: 'gone'),
    CollectionWidgetBinding(widgetId: 3),
    CollectionWidgetBinding(widgetId: 4, collectionId: 'a'),
  ];

  test('boundIds collects each bound collection once', () {
    expect(planner.boundIds(bindings), {'a', 'gone'});
  });

  test('live collections show their title, deleted ones the removed state, '
      'unbound widgets are left alone', () {
    expect(planner.plan(bindings, {'a': 'Coffee'}), const [
      CollectionWidgetTile.live(widgetId: 1, title: 'Coffee'),
      CollectionWidgetTile.removed(widgetId: 2),
      CollectionWidgetTile.live(widgetId: 4, title: 'Coffee'),
    ]);
  });

  test('a target matches a case-insensitive title substring', () {
    const target = CollectionWidgetTarget(collectionId: 'a', title: 'Coffee');
    expect(target.matches(''), isTrue);
    expect(target.matches(' cOF '), isTrue);
    expect(target.matches('tea'), isFalse);
  });
}
