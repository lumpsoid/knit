import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:knit/l10n/app_localizations.dart';

/// One image in an [ImageGalleryPage] — a widget-owned view-model (widgets.md
/// §1): the decoded [bytes], a [heroTag] shared with the feed thumbnail, and an
/// optional [caption].
@immutable
class GalleryImage {
  const GalleryImage({
    required this.bytes,
    required this.heroTag,
    this.caption,
  });

  final Uint8List bytes;
  final Object heroTag;
  final String? caption;
}

/// A full-screen, swipeable, pinch-to-zoom image viewer (§4.2). Pushed when an
/// image bubble (or the cover) is tapped, opening on [initialIndex].
///
/// Swipe left/right to page between [images]. While an image is zoomed in, a
/// one-finger drag pans it instead; once its left/right edge is flush with the
/// screen, the next outward swipe turns the page. Double-tap toggles zoom;
/// a single tap or the close button dismisses the viewer.
class ImageGalleryPage extends StatefulWidget {
  ImageGalleryPage({super.key, required this.images, this.initialIndex = 0})
    : assert(images.isNotEmpty),
      assert(initialIndex >= 0 && initialIndex < images.length);

  final List<GalleryImage> images;
  final int initialIndex;

  static Route<void> route({
    required List<GalleryImage> images,
    int initialIndex = 0,
  }) => MaterialPageRoute<void>(
    fullscreenDialog: true,
    builder: (_) =>
        ImageGalleryPage(images: images, initialIndex: initialIndex),
  );

  @override
  State<ImageGalleryPage> createState() => _ImageGalleryPageState();
}

class _ImageGalleryPageState extends State<ImageGalleryPage> {
  static const Duration _pageTurnDuration = Duration(milliseconds: 250);

  late final PageController _pages = PageController(
    initialPage: widget.initialIndex,
  );
  late int _index = widget.initialIndex;

  /// Whether the current page is zoomed in. While it is, the [PageView] stops
  /// taking drags so they pan the image; paging then happens via edge swipes.
  bool _zoomed = false;

  @override
  void dispose() {
    _pages.dispose();
    super.dispose();
  }

  /// Turn one page in [direction] (-1 previous, +1 next); a no-op past either end.
  void _turn(int direction) {
    final target = _index + direction;
    if (target < 0 || target >= widget.images.length) return;
    _pages.animateToPage(
      target,
      duration: _pageTurnDuration,
      curve: Curves.easeOut,
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final caption = widget.images[_index].caption?.trim();
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          tooltip: l10n.actionClose,
          icon: const Icon(Icons.close),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: Stack(
        children: [
          Positioned.fill(
            // PageView keeps no off-screen pages (zero cache extent), so a page
            // swiped away is disposed and re-opens at 1x when swiped back to.
            child: PageView.builder(
              controller: _pages,
              physics: _zoomed ? const NeverScrollableScrollPhysics() : null,
              itemCount: widget.images.length,
              onPageChanged: (i) => setState(() {
                _index = i;
                _zoomed = false;
              }),
              itemBuilder: (context, i) => _ZoomableImage(
                image: widget.images[i],
                onZoomChanged: (zoomed) {
                  if (i == _index && zoomed != _zoomed) {
                    setState(() => _zoomed = zoomed);
                  }
                },
                onEdgeSwipe: _turn,
                onTap: () => Navigator.of(context).pop(),
              ),
            ),
          ),
          if (caption != null && caption.isNotEmpty)
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: Container(
                width: double.infinity,
                color: Colors.black.withValues(alpha: 0.5),
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
                child: SafeArea(
                  top: false,
                  child: Text(
                    caption,
                    style: const TextStyle(color: Colors.white),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// One gallery page: an [InteractiveViewer] over a single image, with
/// double-tap zoom and edge-swipe detection while zoomed.
class _ZoomableImage extends StatefulWidget {
  const _ZoomableImage({
    required this.image,
    required this.onZoomChanged,
    required this.onEdgeSwipe,
    required this.onTap,
  });

  final GalleryImage image;

  /// Fired when the image crosses between 1x and zoomed in.
  final ValueChanged<bool> onZoomChanged;

  /// Fired with -1 (previous) / +1 (next) when the user swipes outward while
  /// the zoomed image's left / right edge is already flush with the screen.
  final ValueChanged<int> onEdgeSwipe;

  final VoidCallback onTap;

  @override
  State<_ZoomableImage> createState() => _ZoomableImageState();
}

class _ZoomableImageState extends State<_ZoomableImage>
    with SingleTickerProviderStateMixin {
  static const double _maxScale = 5;
  static const double _doubleTapScale = 2.5;

  /// How far a one-finger drag must travel outward at an edge to turn the page.
  static const double _edgeSwipeDistance = 48;

  /// Slack (logical px) when deciding the image edge is flush with the screen.
  static const double _edgeTolerance = 0.5;

  /// Scale above 1 that counts as zoomed (absorbs float noise near 1x).
  static const double _zoomEpsilon = 0.01;

  static const Duration _zoomDuration = Duration(milliseconds: 200);

  final TransformationController _transform = TransformationController();
  late final AnimationController _zoomAnimation = AnimationController(
    vsync: this,
    duration: _zoomDuration,
  )..addListener(_onZoomTick);
  Animation<Matrix4>? _zoomTween;

  Size _viewport = Size.zero;
  bool _zoomed = false;
  Offset _doubleTapAt = Offset.zero;

  // Tracking for the gesture in progress, to detect an edge swipe at its end.
  int? _edgeAtStart;
  Offset _drag = Offset.zero;
  bool _multiTouch = false;

  @override
  void initState() {
    super.initState();
    _transform.addListener(_onTransformChanged);
  }

  @override
  void dispose() {
    _transform
      ..removeListener(_onTransformChanged)
      ..dispose();
    _zoomAnimation.dispose();
    super.dispose();
  }

  double get _scale => _transform.value.getMaxScaleOnAxis();

  void _onTransformChanged() {
    final zoomed = _scale > 1 + _zoomEpsilon;
    if (zoomed == _zoomed) return;
    setState(() => _zoomed = zoomed);
    widget.onZoomChanged(zoomed);
  }

  /// Which horizontal edge of the zoomed image is flush with the screen: -1 its
  /// left edge, +1 its right edge, null neither (or not zoomed). The child fills
  /// the viewport with no boundary margin, so the x translation is clamped to
  /// `[-(scale - 1) * width, 0]`.
  int? _flushEdge() {
    if (!_zoomed) return null;
    final tx = _transform.value.getTranslation().x;
    if (tx >= -_edgeTolerance) return -1;
    if (tx <= -(_scale - 1) * _viewport.width + _edgeTolerance) return 1;
    return null;
  }

  void _onInteractionStart(ScaleStartDetails details) {
    _zoomAnimation.stop();
    _edgeAtStart = _flushEdge();
    _drag = Offset.zero;
    _multiTouch = details.pointerCount > 1;
  }

  void _onInteractionUpdate(ScaleUpdateDetails details) {
    if (details.pointerCount > 1) _multiTouch = true;
    _drag += details.focalPointDelta;
  }

  void _onInteractionEnd(ScaleEndDetails details) {
    final edge = _edgeAtStart;
    _edgeAtStart = null;
    if (_multiTouch || edge == null || edge != _flushEdge()) return;
    if (_drag.dx.abs() < _edgeSwipeDistance ||
        _drag.dx.abs() < _drag.dy.abs()) {
      return;
    }
    // Dragging rightwards at the left edge pulls in the previous image, and
    // leftwards at the right edge the next one.
    if (edge == -1 && _drag.dx > 0) widget.onEdgeSwipe(-1);
    if (edge == 1 && _drag.dx < 0) widget.onEdgeSwipe(1);
  }

  /// Zoom to [_doubleTapScale] around the tapped point, or back to 1x.
  void _onDoubleTap() {
    final Matrix4 target;
    if (_zoomed) {
      target = Matrix4.identity();
    } else {
      // Keep the tapped point under the finger: t = -p * (s - 1), clamped to
      // the viewer's bounds so the image never pulls away from an edge.
      const s = _doubleTapScale;
      final tx = (-_doubleTapAt.dx * (s - 1)).clamp(
        -(s - 1) * _viewport.width,
        0.0,
      );
      final ty = (-_doubleTapAt.dy * (s - 1)).clamp(
        -(s - 1) * _viewport.height,
        0.0,
      );
      target = Matrix4.diagonal3Values(s, s, 1)..setTranslationRaw(tx, ty, 0);
    }
    _zoomTween = Matrix4Tween(
      begin: _transform.value,
      end: target,
    ).animate(CurvedAnimation(parent: _zoomAnimation, curve: Curves.easeOut));
    _zoomAnimation.forward(from: 0);
  }

  void _onZoomTick() {
    final tween = _zoomTween;
    if (tween != null) _transform.value = tween.value;
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        _viewport = constraints.biggest;
        return GestureDetector(
          onTap: widget.onTap,
          onDoubleTapDown: (details) => _doubleTapAt = details.localPosition,
          onDoubleTap: _onDoubleTap,
          child: InteractiveViewer(
            transformationController: _transform,
            minScale: 1,
            maxScale: _maxScale,
            // At 1x a drag belongs to the PageView (paging); only pinch zooms.
            panEnabled: _zoomed,
            onInteractionStart: _onInteractionStart,
            onInteractionUpdate: _onInteractionUpdate,
            onInteractionEnd: _onInteractionEnd,
            child: Center(
              child: Hero(
                tag: widget.image.heroTag,
                child: Image.memory(widget.image.bytes, fit: BoxFit.contain),
              ),
            ),
          ),
        );
      },
    );
  }
}
