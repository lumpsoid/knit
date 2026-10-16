import 'package:knit/features/share_capture/domain/shared_item.dart';

/// Narrow port for shares arriving from other apps (§4.7). The adapter owns
/// the platform plugin; the app-wide controller only sees [SharedItem]s.
abstract interface class IncomingShareSource {
  /// The share that launched the app (cold start), or empty.
  Future<List<SharedItem>> initial();

  /// Shares that arrive while the app is running (warm start).
  Stream<List<SharedItem>> get shares;

  /// Mark the current share consumed, so a relaunch does not deliver it again.
  Future<void> reset();
}
