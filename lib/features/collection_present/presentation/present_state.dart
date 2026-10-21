import 'package:flutter/foundation.dart';
import 'package:knit/features/collection_present/domain/present_models.dart';

enum PresentStatus { loading, ready, failed }

/// A presentation's state (§4.9) — a [ChangeNotifier] the [PresentController]
/// owns and mutates, and the page listens to.
class PresentState extends ChangeNotifier {
  PresentStatus _status = PresentStatus.loading;
  SlideDeck? _deck;
  int _index = 0;
  int? _resumeIndex;
  bool _overlayVisible = true;

  PresentStatus get status => _status;

  /// The planned slides; null until loaded.
  SlideDeck? get deck => _deck;

  /// The slide on screen.
  int get index => _index;

  /// The slide the last presentation was left on, offered on the title slide
  /// until the viewer moves on; null when there is nothing to continue.
  int? get resumeIndex => _resumeIndex;

  /// Whether the thin overlay (close, progress) shows over the slides.
  bool get overlayVisible => _overlayVisible;

  void showDeck(SlideDeck deck, {int? resumeIndex}) {
    _status = PresentStatus.ready;
    _deck = deck;
    _index = 0;
    _resumeIndex = resumeIndex;
    notifyListeners();
  }

  void showFailure() {
    _status = PresentStatus.failed;
    notifyListeners();
  }

  /// Moving off the title slide drops the resume offer and the overlay.
  void moveTo(int index) {
    if (index == _index) return;
    _index = index;
    if (index != 0) {
      _resumeIndex = null;
      _overlayVisible = false;
    }
    notifyListeners();
  }

  void toggleOverlay() {
    _overlayVisible = !_overlayVisible;
    notifyListeners();
  }
}
