import 'package:flutter_test/flutter_test.dart';
import 'package:knit/features/new_collection/domain/similar_collection.dart';

/// The duplicate hint behind the new-collection line: identical (folded) titles
/// win, otherwise every typed word must start a word of the title, and very
/// short input matches nothing.
void main() {
  const espresso = CollectionTitle(
    collectionId: 'c1',
    title: 'Espresso dialing-in',
  );
  const espressoOld = CollectionTitle(
    collectionId: 'c2',
    title: 'Espresso beans',
  );
  const cafe = CollectionTitle(collectionId: 'c3', title: 'Café list');
  const existing = [espresso, espressoOld, cafe];

  CollectionTitle? find(String typed) =>
      SimilarCollectionFinder.find(typed, existing);

  test('an identical title matches, ignoring case and spacing', () {
    expect(find('  espresso   BEANS '), espressoOld);
  });

  test('an identical title beats an earlier partial match', () {
    expect(find('Espresso beans'), espressoOld);
  });

  test('typed words that start the title words match, recency first', () {
    expect(find('espr'), espresso);
    expect(find('beans esp'), espressoOld);
  });

  test('accents are folded', () {
    expect(find('cafe'), cafe);
  });

  test('a word inside another word does not match', () {
    expect(find('presso'), isNull);
  });

  test('a word the title lacks does not match', () {
    expect(find('espresso grinder'), isNull);
  });

  test('input shorter than the minimum matches nothing', () {
    expect(find('es'), isNull);
    expect(find('   '), isNull);
  });
}
