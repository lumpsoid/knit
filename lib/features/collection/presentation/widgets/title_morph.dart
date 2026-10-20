import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/scheduler.dart';

/// How far (in pixels) the feed must scroll to carry the name from the card
/// into the bar, at least. A short name would otherwise snap across.
const double _kMinFlightSpan = 48;

/// Ties the collection name in the feed's title card ([TitleMorphSource]) to
/// its slot in the app bar ([TitleMorphTarget]), so the name flies from one to
/// the other as the card scrolls under the bar ([TitleMorphFlight]), and the
/// rest of the bar fades in alongside it ([TitleMorphReveal]).
///
/// Everything here reads the two boxes' on-screen positions at paint time, once
/// the frame's layout is final, so the flying name never lags the card. The
/// feed calls [markMoved] whenever its header may have moved.
class TitleMorphLink extends ChangeNotifier {
  _RenderTitleMorphSource? _source;
  _RenderTitleMorphTarget? _target;

  /// Each end's width, recorded as it lays out (another box's size can't be
  /// read during layout) — the flying copies lay their text out at it.
  double? _sourceWidth;
  double? _targetWidth;

  /// Bumped (after the frame) when either end changes size, so the flying
  /// copies lay their text out at the new width.
  final ValueNotifier<int> _resized = ValueNotifier(0);
  bool _resizeScheduled = false;
  bool _disposed = false;

  /// How far the name has travelled: 0 while it sits whole in the card, 1 once
  /// it is docked in the bar (also while the card isn't built, e.g. older pages
  /// remain). Null while the bar has no slot for it (the selection bar), so
  /// the card keeps its name and nothing flies. Only valid after layout.
  double? get progress {
    final target = _target;
    if (target == null || !target.hasSize) return null;
    final source = _source;
    if (source == null || !source.hasSize) return 1;
    final Object? viewport = RenderAbstractViewport.maybeOf(source);
    if (viewport is! RenderBox || !viewport.hasSize) return 1;
    // The name starts to leave once its top passes under the feed's top edge.
    final edge = viewport.localToGlobal(Offset.zero).dy;
    final top = source.localToGlobal(Offset.zero).dy;
    final span = math.max(source.size.height, _kMinFlightSpan);
    return ((edge - top) / span).clamp(0.0, 1.0);
  }

  /// The card's name, in global coordinates; null while it isn't built.
  Rect? get _sourceRect => _globalRect(_source);

  /// The bar's name slot, in global coordinates.
  Rect? get _targetRect => _globalRect(_target);

  static Rect? _globalRect(RenderBox? box) {
    if (box == null || !box.attached || !box.hasSize) return null;
    return box.localToGlobal(Offset.zero) & box.size;
  }

  /// The card's name may have moved on screen (a scroll, a layout change):
  /// repaint everything that follows it.
  void markMoved() {
    if (!_disposed) notifyListeners();
  }

  void _attach(RenderBox box) {
    switch (box) {
      case _RenderTitleMorphSource():
        _source = box;
      case _RenderTitleMorphTarget():
        _target = box;
    }
    _scheduleResize();
  }

  void _detach(RenderBox box) {
    if (identical(_source, box)) {
      _source = null;
      _sourceWidth = null;
    }
    if (identical(_target, box)) {
      _target = null;
      _targetWidth = null;
    }
    markMoved();
  }

  /// Relayout the flying copies once this frame is done — they lay out after
  /// the card and the bar, but mustn't be dirtied while those lay out.
  void _scheduleResize() {
    markMoved();
    if (_resizeScheduled) return;
    _resizeScheduled = true;
    SchedulerBinding.instance
      ..addPostFrameCallback((_) {
        _resizeScheduled = false;
        if (!_disposed) _resized.value++;
      })
      ..ensureVisualUpdate();
  }

  @override
  void dispose() {
    _disposed = true;
    _resized.dispose();
    super.dispose();
  }
}

/// Marks the collection name in the title card. It paints as usual while the
/// name sits in the card and steps aside once the name takes flight.
class TitleMorphSource extends SingleChildRenderObjectWidget {
  const TitleMorphSource({super.key, required this.link, super.child});

  final TitleMorphLink link;

  @override
  RenderObject createRenderObject(BuildContext context) =>
      _RenderTitleMorphSource(link);

  @override
  void updateRenderObject(BuildContext context, RenderObject renderObject) =>
      (renderObject as _RenderTitleMorphEnd).link = link;
}

/// Marks the name's slot in the app bar. It lays out (and keeps its semantics
/// and taps) but never paints: [TitleMorphFlight] draws the name there.
class TitleMorphTarget extends SingleChildRenderObjectWidget {
  const TitleMorphTarget({super.key, required this.link, super.child});

  final TitleMorphLink link;

  @override
  RenderObject createRenderObject(BuildContext context) =>
      _RenderTitleMorphTarget(link);

  @override
  void updateRenderObject(BuildContext context, RenderObject renderObject) =>
      (renderObject as _RenderTitleMorphEnd).link = link;
}

/// Shared bookkeeping of the two ends: register with the link while attached,
/// repaint when it moves, and report size changes.
abstract class _RenderTitleMorphEnd extends RenderProxyBox {
  _RenderTitleMorphEnd(this._link);

  TitleMorphLink _link;
  set link(TitleMorphLink value) {
    if (identical(value, _link)) return;
    if (attached) _unlink();
    _link = value;
    if (attached) _relink();
  }

  void _relink() {
    _link
      ..addListener(markNeedsPaint)
      .._attach(this);
  }

  void _unlink() {
    _link
      ..removeListener(markNeedsPaint)
      .._detach(this);
  }

  @override
  void attach(PipelineOwner owner) {
    super.attach(owner);
    _relink();
  }

  @override
  void detach() {
    _unlink();
    super.detach();
  }

  @override
  void performLayout() {
    final before = hasSize ? size : null;
    super.performLayout();
    switch (this) {
      case _RenderTitleMorphSource():
        _link._sourceWidth = size.width;
      case _RenderTitleMorphTarget():
        _link._targetWidth = size.width;
    }
    if (before != size) _link._scheduleResize();
  }
}

class _RenderTitleMorphSource extends _RenderTitleMorphEnd {
  _RenderTitleMorphSource(super.link);

  @override
  void paint(PaintingContext context, Offset offset) {
    if ((_link.progress ?? 0) > 0) return;
    super.paint(context, offset);
  }
}

class _RenderTitleMorphTarget extends _RenderTitleMorphEnd {
  _RenderTitleMorphTarget(super.link);

  @override
  void paint(PaintingContext context, Offset offset) {}
}

/// The flying name, laid over the whole page: the card's styling fades into
/// the bar's as the name moves and scales from the card to its slot in the
/// bar. Draws nothing while the name sits in the card. Place it in a
/// [Stack] over the page's [Scaffold].
class TitleMorphFlight extends StatelessWidget {
  const TitleMorphFlight({
    super.key,
    required this.link,
    required this.title,
    required this.sourceStyle,
    required this.targetStyle,
  });

  final TitleMorphLink link;
  final String title;

  /// The name's style in the card, and in the bar.
  final TextStyle sourceStyle;
  final TextStyle targetStyle;

  @override
  Widget build(BuildContext context) {
    final from = sourceStyle.fontSize ?? 24;
    final to = targetStyle.fontSize ?? 22;
    // The text styles above merge onto the ambient one, as they do in the card
    // and the bar; transparency material gives the same ambient style here.
    return IgnorePointer(
      child: ExcludeSemantics(
        child: Material(
          type: MaterialType.transparency,
          child: Stack(
            fit: StackFit.expand,
            children: [
              _TitleMorphLeg(
                link: link,
                end: _FlightEnd.source,
                startScale: 1,
                endScale: to / from,
                child: Text(title, style: sourceStyle),
              ),
              _TitleMorphLeg(
                link: link,
                end: _FlightEnd.target,
                startScale: from / to,
                endScale: 1,
                child: Text(
                  title,
                  style: targetStyle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Which end's styling a flight leg carries (and lays out at the width of).
enum _FlightEnd { source, target }

class _TitleMorphLeg extends SingleChildRenderObjectWidget {
  const _TitleMorphLeg({
    required this.link,
    required this.end,
    required this.startScale,
    required this.endScale,
    super.child,
  });

  final TitleMorphLink link;
  final _FlightEnd end;
  final double startScale;
  final double endScale;

  @override
  RenderObject createRenderObject(BuildContext context) =>
      _RenderTitleMorphLeg(link, end, startScale, endScale);

  @override
  void updateRenderObject(
    BuildContext context,
    _RenderTitleMorphLeg renderObject,
  ) {
    renderObject
      ..link = link
      ..end = end
      ..startScale = startScale
      ..endScale = endScale;
  }
}

/// One styling of the flying name. Fills the overlay, lays its text out at its
/// end's width, and paints it at the point between the two ends the progress
/// gives — scaled and faded for that point. The source styling fades out over
/// the first part of the flight, the bar's fades in over the last.
class _RenderTitleMorphLeg extends RenderProxyBox {
  _RenderTitleMorphLeg(this._link, this._end, this._startScale, this._endScale);

  static const Curve _fadeOut = Interval(0, 0.7, curve: Curves.easeIn);
  static const Curve _fadeIn = Interval(0.3, 1, curve: Curves.easeOut);

  final LayerHandle<OpacityLayer> _opacityLayer = LayerHandle();
  final LayerHandle<TransformLayer> _transformLayer = LayerHandle();

  TitleMorphLink _link;
  set link(TitleMorphLink value) {
    if (identical(value, _link)) return;
    if (attached) _unlisten();
    _link = value;
    if (attached) _listen();
    markNeedsLayout();
  }

  _FlightEnd _end;
  set end(_FlightEnd value) {
    if (value == _end) return;
    _end = value;
    markNeedsLayout();
  }

  double _startScale;
  set startScale(double value) {
    if (value == _startScale) return;
    _startScale = value;
    markNeedsPaint();
  }

  double _endScale;
  set endScale(double value) {
    if (value == _endScale) return;
    _endScale = value;
    markNeedsPaint();
  }

  void _listen() {
    _link.addListener(markNeedsPaint);
    _link._resized.addListener(markNeedsLayout);
  }

  void _unlisten() {
    _link.removeListener(markNeedsPaint);
    _link._resized.removeListener(markNeedsLayout);
  }

  @override
  void attach(PipelineOwner owner) {
    super.attach(owner);
    _listen();
  }

  @override
  void detach() {
    _unlisten();
    super.detach();
  }

  @override
  void dispose() {
    _opacityLayer.layer = null;
    _transformLayer.layer = null;
    super.dispose();
  }

  // Its own layer: it repaints on every scroll frame, the page around it
  // shouldn't.
  @override
  bool get isRepaintBoundary => true;

  @override
  bool get alwaysNeedsCompositing => child != null;

  @override
  void performLayout() {
    size = constraints.biggest;
    final width = _end == _FlightEnd.source
        ? _link._sourceWidth
        : _link._targetWidth;
    child?.layout(
      width == null
          ? constraints.loosen()
          : BoxConstraints.tightFor(width: width),
    );
  }

  @override
  void paint(PaintingContext context, Offset offset) {
    final child = this.child;
    final t = _link.progress;
    final to = _link._targetRect;
    if (child == null || t == null || t <= 0 || to == null) return _clear();
    // With no card built the name is simply docked.
    final from = _link._sourceRect ?? to;
    final opacity = _end == _FlightEnd.source
        ? 1 - _fadeOut.transform(t)
        : _fadeIn.transform(t);
    if (opacity <= 0) return _clear();
    final at = globalToLocal(Offset.lerp(from.topLeft, to.topLeft, t)!);
    final scale = _startScale + (_endScale - _startScale) * t;
    final transform = Matrix4.translationValues(at.dx, at.dy, 0)
      ..scaleByDouble(scale, scale, 1, 1);
    _opacityLayer.layer = context.pushOpacity(offset, (opacity * 255).round(), (
      context,
      offset,
    ) {
      _transformLayer.layer = context.pushTransform(
        needsCompositing,
        offset,
        transform,
        (context, offset) => context.paintChild(child, offset),
        oldLayer: _transformLayer.layer,
      );
    }, oldLayer: _opacityLayer.layer);
  }

  void _clear() {
    _opacityLayer.layer = null;
    _transformLayer.layer = null;
  }
}

/// Bar furniture that arrives with the name: fades (and, from [fromScale],
/// grows) in step with the flight, and only takes taps once mostly in. Hidden
/// while the bar has no name slot.
class TitleMorphReveal extends SingleChildRenderObjectWidget {
  const TitleMorphReveal({
    super.key,
    required this.link,
    this.fromScale = 1,
    super.child,
  });

  final TitleMorphLink link;

  /// The child's scale while the name is still in the card.
  final double fromScale;

  @override
  RenderObject createRenderObject(BuildContext context) =>
      _RenderTitleMorphReveal(link, fromScale);

  @override
  void updateRenderObject(BuildContext context, RenderObject renderObject) {
    (renderObject as _RenderTitleMorphReveal)
      ..link = link
      ..fromScale = fromScale;
  }
}

class _RenderTitleMorphReveal extends RenderProxyBox {
  _RenderTitleMorphReveal(this._link, this._fromScale);

  final LayerHandle<OpacityLayer> _opacityLayer = LayerHandle();
  final LayerHandle<TransformLayer> _transformLayer = LayerHandle();

  TitleMorphLink _link;
  set link(TitleMorphLink value) {
    if (identical(value, _link)) return;
    if (attached) _link.removeListener(markNeedsPaint);
    _link = value;
    if (attached) _link.addListener(markNeedsPaint);
    markNeedsPaint();
  }

  double _fromScale;
  set fromScale(double value) {
    if (value == _fromScale) return;
    _fromScale = value;
    markNeedsPaint();
  }

  double get _shown => Curves.easeOut.transform(_link.progress ?? 0);

  @override
  void attach(PipelineOwner owner) {
    super.attach(owner);
    _link.addListener(markNeedsPaint);
  }

  @override
  void detach() {
    _link.removeListener(markNeedsPaint);
    super.detach();
  }

  @override
  void dispose() {
    _opacityLayer.layer = null;
    _transformLayer.layer = null;
    super.dispose();
  }

  @override
  bool get isRepaintBoundary => true;

  @override
  bool get alwaysNeedsCompositing => child != null;

  @override
  bool hitTest(BoxHitTestResult result, {required Offset position}) =>
      _shown >= 0.5 && super.hitTest(result, position: position);

  @override
  void paint(PaintingContext context, Offset offset) {
    final child = this.child;
    final shown = _shown;
    if (child == null || shown <= 0) {
      _opacityLayer.layer = null;
      _transformLayer.layer = null;
      return;
    }
    final scale = _fromScale + (1 - _fromScale) * shown;
    final center = size.center(Offset.zero);
    final transform = Matrix4.translationValues(center.dx, center.dy, 0)
      ..scaleByDouble(scale, scale, 1, 1)
      ..translateByDouble(-center.dx, -center.dy, 0, 1);
    _opacityLayer.layer = context.pushOpacity(offset, (shown * 255).round(), (
      context,
      offset,
    ) {
      _transformLayer.layer = context.pushTransform(
        needsCompositing,
        offset,
        transform,
        (context, offset) => context.paintChild(child, offset),
        oldLayer: _transformLayer.layer,
      );
    }, oldLayer: _opacityLayer.layer);
  }
}
