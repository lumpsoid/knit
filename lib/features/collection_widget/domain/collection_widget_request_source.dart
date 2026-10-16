import 'package:knit/features/collection_widget/domain/collection_widget_request.dart';

/// Narrow port for widget taps arriving from the launcher. The adapter owns the
/// platform channel; the app-wide controller only sees
/// [CollectionWidgetRequest]s.
abstract interface class CollectionWidgetRequestSource {
  /// The request that launched the app (cold start), or null. Consumed — a
  /// second call returns null.
  Future<CollectionWidgetRequest?> initial();

  /// Requests that arrive while the app is running (warm start).
  Stream<CollectionWidgetRequest> get requests;
}
