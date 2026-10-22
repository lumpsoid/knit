import 'package:knit/features/collection_present/domain/screen_awake_port.dart';

/// [ScreenAwakePort] shared by every presentation on the stack (§4.9): each
/// one holds the screen on, and it may sleep only once the last lets go — so
/// closing a presentation opened on top of another keeps the screen awake.
class SharedScreenAwake implements ScreenAwakePort {
  SharedScreenAwake(this._inner);

  final ScreenAwakePort _inner;
  int _holders = 0;

  @override
  Future<void> keepOn({required bool enabled}) async {
    if (enabled) {
      if (_holders++ == 0) await _inner.keepOn(enabled: true);
    } else if (_holders > 0 && --_holders == 0) {
      await _inner.keepOn(enabled: false);
    }
  }
}
