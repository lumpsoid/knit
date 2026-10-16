import 'package:flutter/foundation.dart';
import 'package:knit/features/share_capture/domain/shared_item.dart';

/// The share waiting to be handled (§4.7) — app-wide, owned and mutated by the
/// [IncomingShareController]; the [IncomingShareGate] listens to it. A newer
/// share replaces one nobody has taken yet.
class IncomingShareState extends ChangeNotifier {
  List<SharedItem>? _pending;

  List<SharedItem>? get pending => _pending;
  bool get hasPending => _pending != null;

  void offer(List<SharedItem> items) {
    _pending = items;
    notifyListeners();
  }

  /// Hand out the pending share and clear it.
  List<SharedItem>? take() {
    final items = _pending;
    if (items == null) return null;
    _pending = null;
    notifyListeners();
    return items;
  }
}
