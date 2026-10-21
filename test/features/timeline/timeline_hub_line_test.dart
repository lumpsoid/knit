import 'package:flutter_test/flutter_test.dart';
import 'package:knit/features/timeline/domain/timeline_hub_line.dart';

/// A home row's "in:" line (§4.1): two names, then "+N".
void main() {
  test('no hubs, no line', () {
    expect(TimelineHubLine.of(const []), isNull);
  });

  test('up to two names are all shown', () {
    expect(
      TimelineHubLine.of(const ['House']),
      const TimelineHubLine(names: ['House']),
    );
    expect(
      TimelineHubLine.of(const ['House', 'Trips']),
      const TimelineHubLine(names: ['House', 'Trips']),
    );
  });

  test('past two, the rest are counted', () {
    expect(
      TimelineHubLine.of(const ['A', 'B', 'C', 'D']),
      const TimelineHubLine(names: ['A', 'B'], more: 2),
    );
  });
}
