import 'package:flutter/material.dart';

/// A slide's scrolling text (§4.9). Short content doesn't scroll, so a swipe
/// over it turns the slide as usual. Long content scrolls first, and once it
/// reaches an end, pulling on past it turns to the next or previous slide.
class SlideScroll extends StatefulWidget {
  const SlideScroll({
    super.key,
    required this.child,
    required this.onNext,
    required this.onPrevious,
    this.padding = EdgeInsets.zero,
  });

  final Widget child;
  final VoidCallback onNext;
  final VoidCallback onPrevious;
  final EdgeInsetsGeometry padding;

  @override
  State<SlideScroll> createState() => _SlideScrollState();
}

class _SlideScrollState extends State<SlideScroll> {
  /// How far a drag must pull past an end to turn the slide.
  static const double _turnDistance = 56;

  double _overscroll = 0;
  bool _turned = false;

  bool _onScroll(ScrollNotification n) {
    if (n.depth != 0) return false;
    switch (n) {
      case ScrollStartNotification():
        _overscroll = 0;
        _turned = false;
      case OverscrollNotification(:final overscroll, :final dragDetails)
          when dragDetails != null && !_turned:
        _overscroll += overscroll;
        if (_overscroll >= _turnDistance) {
          _turned = true;
          widget.onNext();
        } else if (_overscroll <= -_turnDistance) {
          _turned = true;
          widget.onPrevious();
        }
      default:
        break;
    }
    return false;
  }

  @override
  Widget build(BuildContext context) =>
      NotificationListener<ScrollNotification>(
        onNotification: _onScroll,
        child: SingleChildScrollView(
          // Clamping, so an end reports overscroll on every platform.
          physics: const ClampingScrollPhysics(),
          padding: widget.padding,
          child: widget.child,
        ),
      );
}
