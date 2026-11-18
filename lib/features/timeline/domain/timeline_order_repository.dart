import 'package:knit/features/timeline/domain/timeline_failure.dart';
import 'package:knit/features/timeline/domain/timeline_order.dart';
import 'package:result_dart/result_dart.dart';

/// Narrow read port for the manual Home order (business_logic.md §5). The order
/// is a **device-local** view preference — never synced or signed — so another
/// device's Home is unaffected. A first run with nothing persisted yields an
/// empty order (the recency order), not a failure.
abstract interface class TimelineOrderReadRepository {
  Future<Result<TimelineOrder, TimelineFailure>> loadOrder();
}

/// Narrow write port for the manual Home order (business_logic.md §5). Replaces
/// the stored order with the full [TimelineOrder] the domain computed and
/// returns it; an empty order clears the stored one.
abstract interface class TimelineOrderWriteRepository {
  /// Replaces the stored order with [order] and returns it; an empty order clears it.
  Future<Result<TimelineOrder, TimelineFailure>> saveOrder(TimelineOrder order);
}
