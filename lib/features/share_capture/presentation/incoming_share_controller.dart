import 'dart:async';

import 'package:knit/features/share_capture/domain/incoming_share_source.dart';
import 'package:knit/features/share_capture/domain/shared_item.dart';
import 'package:knit/features/share_capture/presentation/incoming_share_state.dart';
import 'package:logging/logging.dart';

/// The app-wide receiver of shares from other apps (§4.7): collects the share
/// that launched the app and every later one into [state], where the
/// [IncomingShareGate] of the current page picks it up with [take].
class IncomingShareController {
  IncomingShareController({required IncomingShareSource source, Logger? logger})
    : _source = source,
      _log = logger ?? Logger('knit.share_capture');

  final IncomingShareSource _source;
  final Logger _log;

  final IncomingShareState state = IncomingShareState();

  StreamSubscription<List<SharedItem>>? _subscription;

  /// Start listening for warm shares, then read the cold-start one.
  Future<void> start() async {
    _subscription ??= _source.shares.listen(
      _receive,
      onError: (Object e, StackTrace st) =>
          _log.severe('receiving a share failed', e, st),
    );
    try {
      _receive(await _source.initial());
    } catch (e, st) {
      _log.severe('reading the launch share failed', e, st);
    }
  }

  void _receive(List<SharedItem> items) {
    if (items.isEmpty) return;
    state.offer(items);
  }

  /// Take the pending share (null when there is none) and mark it consumed on
  /// the platform side, so it is not delivered again.
  List<SharedItem>? take() {
    final items = state.take();
    if (items != null) unawaited(_reset());
    return items;
  }

  Future<void> _reset() async {
    try {
      await _source.reset();
    } catch (e, st) {
      _log.severe('resetting the share failed', e, st);
    }
  }

  void dispose() {
    unawaited(_subscription?.cancel());
    state.dispose();
  }
}
