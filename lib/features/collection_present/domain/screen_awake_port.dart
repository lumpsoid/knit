/// Narrow port for keeping the screen on while presenting (§4.9).
abstract interface class ScreenAwakePort {
  Future<void> keepOn({required bool enabled});
}
