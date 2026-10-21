import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:knit/features/collection/presentation/image_gallery_page.dart';
import 'package:knit/features/collection_present/domain/present_models.dart';
import 'package:knit/features/collection_present/presentation/present_controller.dart';
import 'package:knit/features/collection_present/presentation/present_state.dart';
import 'package:knit/features/collection_present/presentation/widgets/card_slide_view.dart';
import 'package:knit/features/collection_present/presentation/widgets/slide_photos.dart';
import 'package:knit/features/collection_present/presentation/widgets/title_slide_view.dart';
import 'package:knit/features/connections/presentation/connections_page.dart';
import 'package:knit/l10n/app_localizations.dart';

/// Presents a collection full screen (§4.9): its slides one above the next,
/// swiped up and down, from the title slide on. A tap on a slide shows or
/// hides the thin overlay (close, position, previous / next); arrow keys,
/// Page Up / Down and Space turn slides too. The system bars stay hidden and
/// the screen stays on while it shows.
class PresentPage extends StatefulWidget {
  const PresentPage({super.key, required this.controller});

  final PresentController controller;

  static Route<void> route(PresentController controller) =>
      MaterialPageRoute<void>(
        builder: (_) => PresentPage(controller: controller),
      );

  @override
  State<PresentPage> createState() => _PresentPageState();
}

class _PresentPageState extends State<PresentPage> {
  static const Duration _turnDuration = Duration(milliseconds: 350);

  final PageController _pages = PageController();

  PresentController get _controller => widget.controller;

  @override
  void initState() {
    super.initState();
    unawaited(
      SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky),
    );
    unawaited(_controller.load());
  }

  @override
  void dispose() {
    unawaited(
      SystemChrome.setEnabledSystemUIMode(
        SystemUiMode.manual,
        overlays: SystemUiOverlay.values,
      ),
    );
    _pages.dispose();
    _controller.dispose();
    super.dispose();
  }

  // --- navigation ------------------------------------------------------------

  void _goTo(int index) {
    final deck = _controller.state.deck;
    if (deck == null || index < 0 || index >= deck.length) return;
    if (!_pages.hasClients) return;
    unawaited(
      _pages.animateToPage(
        index,
        duration: _turnDuration,
        curve: Curves.easeOutCubic,
      ),
    );
  }

  void _next() => _goTo(_controller.state.index + 1);
  void _previous() => _goTo(_controller.state.index - 1);

  Future<void> _openLink(PresentLink link) async {
    final index = _controller.openLink(link);
    if (index != null) {
      _goTo(index);
      return;
    }
    await Navigator.of(context).push(ConnectionsPage.route());
  }

  Future<void> _openUrl(String url) async {
    final opened = await _controller.openUrl(url);
    if (opened || !mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(AppLocalizations.of(context).collectionLinkOpenFailed),
      ),
    );
  }

  void _openPhotos(List<SlidePhoto> photos, int index) {
    final images = <GalleryImage>[];
    var initialIndex = 0;
    for (var i = 0; i < photos.length; i++) {
      final bytes = photos[i].bytes;
      if (bytes == null) continue;
      if (i == index) initialIndex = images.length;
      images.add(
        GalleryImage(
          bytes: bytes,
          heroTag: presentImageHeroTag(photos[i].id),
          caption: photos[i].caption,
        ),
      );
    }
    if (images.isEmpty) return;
    Navigator.of(
      context,
    ).push(ImageGalleryPage.route(images: images, initialIndex: initialIndex));
  }

  // --- build -----------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    return CallbackShortcuts(
      bindings: {
        const SingleActivator(LogicalKeyboardKey.arrowDown): _next,
        const SingleActivator(LogicalKeyboardKey.arrowRight): _next,
        const SingleActivator(LogicalKeyboardKey.pageDown): _next,
        const SingleActivator(LogicalKeyboardKey.space): _next,
        const SingleActivator(LogicalKeyboardKey.arrowUp): _previous,
        const SingleActivator(LogicalKeyboardKey.arrowLeft): _previous,
        const SingleActivator(LogicalKeyboardKey.pageUp): _previous,
      },
      child: Focus(
        autofocus: true,
        child: Scaffold(
          body: ListenableBuilder(
            listenable: Listenable.merge([
              _controller.state,
              _controller.images,
            ]),
            builder: (context, _) => _body(_controller.state),
          ),
        ),
      ),
    );
  }

  Widget _body(PresentState state) {
    final l10n = AppLocalizations.of(context);
    final deck = state.deck;
    switch (state.status) {
      case PresentStatus.loading:
        return const Center(child: CircularProgressIndicator());
      case PresentStatus.failed:
        return SafeArea(
          child: Stack(
            children: [
              Center(child: Text(l10n.presentLoadFailed)),
              _closeButton(l10n),
            ],
          ),
        );
      case PresentStatus.ready:
        break;
    }
    return Stack(
      children: [
        Positioned.fill(
          child: PageView.builder(
            controller: _pages,
            scrollDirection: Axis.vertical,
            itemCount: deck!.length,
            onPageChanged: _controller.pageChanged,
            itemBuilder: (context, i) => GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: _controller.toggleOverlay,
              child: SafeArea(child: _slide(deck.slides[i], state)),
            ),
          ),
        ),
        Positioned.fill(
          child: IgnorePointer(
            ignoring: !state.overlayVisible,
            child: AnimatedOpacity(
              opacity: state.overlayVisible ? 1 : 0,
              duration: const Duration(milliseconds: 200),
              child: _overlay(l10n, index: state.index, count: deck.length),
            ),
          ),
        ),
      ],
    );
  }

  Widget _slide(Slide slide, PresentState state) {
    final images = _controller.images;
    switch (slide) {
      case TitleSlide(
        :final title,
        :final description,
        :final coverAttachmentId,
      ):
        final cover = coverAttachmentId == null
            ? null
            : SlidePhoto(
                id: coverAttachmentId,
                bytes: images.of(coverAttachmentId),
              );
        final resume = state.resumeIndex;
        return TitleSlideView(
          title: title,
          description: description,
          cover: cover,
          resumeSlideNumber: resume == null ? null : resume + 1,
          hasSlides: (state.deck?.length ?? 0) > 1,
          onResume: () {
            if (resume != null) _goTo(resume);
          },
          onOpenCover: () {
            if (cover != null) _openPhotos([cover], 0);
          },
          onNext: _next,
          onPrevious: _previous,
        );
      case CardSlide(images: final imageCards, :final notes):
        // A card with several images (§4.2) gives the carousel each of them.
        final photos = [
          for (final c in imageCards)
            for (final (i, id) in c.imageIds.indexed)
              SlidePhoto(
                id: i == 0 ? c.id : '${c.id}-$i',
                bytes: images.of(id),
                caption: c.text,
              ),
        ];
        return CardSlideView(
          photos: photos,
          notes: notes,
          photoLinks: [for (final c in imageCards) ...c.links],
          playback: _controller.playback,
          onOpenPhoto: (i) => _openPhotos(photos, i),
          onOpenUrl: (url) => unawaited(_openUrl(url)),
          onToggleAudio: (card) => unawaited(_controller.toggleAudio(card)),
          onOpenLink: (link) => unawaited(_openLink(link)),
          onNext: _next,
          onPrevious: _previous,
        );
    }
  }

  /// The thin overlay: close and position along the top with a progress bar,
  /// previous / next at the bottom right. A solid translucent band, no blur.
  Widget _overlay(
    AppLocalizations l10n, {
    required int index,
    required int count,
  }) {
    final theme = Theme.of(context);
    final band = theme.colorScheme.surface.withValues(alpha: 0.9);
    return Column(
      children: [
        ColoredBox(
          color: band,
          child: SafeArea(
            bottom: false,
            child: Column(
              children: [
                Row(
                  children: [
                    IconButton(
                      tooltip: l10n.actionClose,
                      icon: const Icon(Icons.close),
                      onPressed: () => Navigator.of(context).maybePop(),
                    ),
                    const Spacer(),
                    Padding(
                      padding: const EdgeInsets.only(right: 16),
                      child: Text(
                        l10n.presentSlideCount(index + 1, count),
                        style: theme.textTheme.labelLarge,
                      ),
                    ),
                  ],
                ),
                LinearProgressIndicator(value: (index + 1) / count),
              ],
            ),
          ),
        ),
        const Spacer(),
        SafeArea(
          top: false,
          child: Align(
            alignment: Alignment.bottomRight,
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: DecoratedBox(
                decoration: ShapeDecoration(
                  color: band,
                  shape: const StadiumBorder(),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      tooltip: l10n.presentPreviousTooltip,
                      icon: const Icon(Icons.keyboard_arrow_up),
                      onPressed: index > 0 ? _previous : null,
                    ),
                    IconButton(
                      tooltip: l10n.presentNextTooltip,
                      icon: const Icon(Icons.keyboard_arrow_down),
                      onPressed: index < count - 1 ? _next : null,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _closeButton(AppLocalizations l10n) => Align(
    alignment: Alignment.topLeft,
    child: IconButton(
      tooltip: l10n.actionClose,
      icon: const Icon(Icons.close),
      onPressed: () => Navigator.of(context).maybePop(),
    ),
  );
}
