import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

/// A pull-to-refresh list with a hidden [header] above its [children] (the
/// Archive row on Home, §3.4). A short pull past the top reveals the header and
/// it stays; a longer one also refreshes. Scrolling the header fully out of view
/// hides it again.
///
/// The reveal is a view-only gesture state, so it lives here rather than in
/// the feature's state.
class PullRevealList extends StatefulWidget {
  const PullRevealList({
    super.key,
    required this.header,
    required this.headerHeight,
    this.alwaysShowHeader = false,
    required this.onRefresh,
    required this.children,
  });

  /// The hidden row, or null when there is nothing to reveal.
  final Widget? header;

  /// The [header]'s fixed height: hiding it moves the offset up by this much
  /// so the rows below stay where they are.
  final double headerHeight;

  /// Show the [header] without a pull (e.g. when there are no other rows).
  final bool alwaysShowHeader;

  final Future<void> Function() onRefresh;
  final List<Widget> children;

  /// How far a drag past the top must pull to reveal the header. Shorter than
  /// the refresh trigger, so a long pull reveals *and* refreshes.
  static const double revealPull = 48;

  @override
  State<PullRevealList> createState() => _PullRevealListState();
}

class _PullRevealListState extends State<PullRevealList> {
  final _scroll = ScrollController();

  /// Whether a pull has revealed the header.
  bool _revealed = false;

  /// The overscroll accumulated by the current drag past the top.
  double _pull = 0;

  @override
  void didUpdateWidget(PullRevealList oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Nothing left to reveal: the next header waits for a fresh pull.
    if (widget.header == null) _revealed = false;
  }

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  bool get _headerShown =>
      widget.header != null && (_revealed || widget.alwaysShowHeader);

  void _reveal() {
    if (_revealed || widget.header == null) return;
    setState(() => _revealed = true);
  }

  /// A drag past the top reveals the header: an overscroll under clamping
  /// physics (Android, desktop) or a negative offset under bouncing physics
  /// (iOS). Once a scroll settles with the header fully out of view, it hides.
  bool _onScroll(ScrollNotification n) {
    if (n.depth != 0) return false;
    switch (n) {
      case ScrollStartNotification():
        _pull = 0;
      case OverscrollNotification(:final overscroll, :final dragDetails)
          when dragDetails != null && overscroll < 0:
        _pull -= overscroll;
        if (_pull >= PullRevealList.revealPull) _reveal();
      case ScrollUpdateNotification(:final metrics, :final dragDetails)
          when dragDetails != null &&
              metrics.pixels <= -PullRevealList.revealPull:
        _reveal();
      case ScrollEndNotification(:final metrics)
          when _revealed &&
              !widget.alwaysShowHeader &&
              metrics.pixels >= widget.headerHeight:
        WidgetsBinding.instance.addPostFrameCallback((_) => _hide());
      default:
        break;
    }
    return false;
  }

  void _hide() {
    if (!mounted || !_revealed || !_scroll.hasClients) return;
    final pixels = _scroll.position.pixels;
    if (pixels < widget.headerHeight) return;
    setState(() => _revealed = false);
    _scroll.jumpTo(pixels - widget.headerHeight);
  }

  /// A mouse wheel has no overscroll: scrolling up at the top reveals the
  /// header instead.
  void _onPointerSignal(PointerSignalEvent event) {
    if (event is PointerScrollEvent &&
        event.scrollDelta.dy < 0 &&
        _scroll.hasClients &&
        _scroll.position.pixels <= 0) {
      _reveal();
    }
  }

  @override
  Widget build(BuildContext context) {
    final header = widget.header;
    return Listener(
      onPointerSignal: _onPointerSignal,
      child: NotificationListener<ScrollNotification>(
        onNotification: _onScroll,
        child: RefreshIndicator(
          onRefresh: widget.onRefresh,
          child: ListView(
            controller: _scroll,
            physics: const AlwaysScrollableScrollPhysics(),
            children: [
              if (_headerShown && header != null) _GrowIn(child: header),
              ...widget.children,
            ],
          ),
        ),
      ),
    );
  }
}

/// Grows the header open from nothing when it first appears, so a pull reads
/// as uncovering it rather than as the list jumping.
class _GrowIn extends StatelessWidget {
  const _GrowIn({required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) => TweenAnimationBuilder<double>(
    tween: Tween(begin: 0, end: 1),
    duration: const Duration(milliseconds: 200),
    curve: Curves.easeOut,
    builder: (_, t, child) => ClipRect(
      child: Align(
        alignment: Alignment.bottomCenter,
        heightFactor: t,
        child: child,
      ),
    ),
    child: child,
  );
}
