import 'package:flutter/material.dart';
import 'package:knit/features/collection/presentation/collection_page.dart';
import 'package:knit/features/collection_widget/domain/collection_widget_request.dart';
import 'package:knit/features/collection_widget/presentation/collection_widget_controller.dart';
import 'package:knit/features/collection_widget/presentation/collection_widget_picker_page.dart';
import 'package:knit/features/collection_widget/presentation/collection_widget_scope.dart';
import 'package:knit/l10n/app_localizations.dart';

/// What a page does with a home-screen widget request.
enum CollectionWidgetGateMode {
  /// Open the tapped collection (or the picker for a widget being set up) and
  /// keep the widgets' tiles current while mounted.
  handle,

  /// No identity yet: a tap just lands in onboarding; setting a widget up is
  /// refused with a message.
  reject,
}

/// Wraps a root page (the Timeline, or Onboarding) and handles each pending
/// widget request as [mode] says. Only post-launch pages host it, so a tap
/// that cold-starts the app waits until the graph is up. Inert when the
/// widget isn't wired (other platforms, isolated page tests).
class CollectionWidgetGate extends StatefulWidget {
  const CollectionWidgetGate({
    super.key,
    required this.mode,
    required this.child,
  });

  final CollectionWidgetGateMode mode;
  final Widget child;

  @override
  State<CollectionWidgetGate> createState() => _CollectionWidgetGateState();
}

class _CollectionWidgetGateState extends State<CollectionWidgetGate> {
  final CollectionWidgetController? _widgets = CollectionWidgetScope.controller;

  /// A request is being handled — later ones wait until it is done.
  bool _busy = false;

  /// Leaving the app is when the home screen becomes visible: refresh then.
  AppLifecycleListener? _lifecycle;

  bool get _handles => widget.mode == CollectionWidgetGateMode.handle;

  @override
  void initState() {
    super.initState();
    final widgets = _widgets;
    if (widgets == null) return;
    widgets.state.addListener(_handlePending);
    if (_handles) {
      widgets.attach();
      _lifecycle = AppLifecycleListener(onHide: widgets.refreshTiles);
    }
    WidgetsBinding.instance.addPostFrameCallback((_) => _handlePending());
  }

  @override
  void dispose() {
    final widgets = _widgets;
    if (widgets != null) {
      widgets.state.removeListener(_handlePending);
      if (_handles) widgets.detach();
    }
    _lifecycle?.dispose();
    super.dispose();
  }

  Future<void> _handlePending() async {
    final widgets = _widgets;
    if (widgets == null || _busy || !mounted) return;
    if (!widgets.state.hasPending) return;
    final request = widgets.take();
    if (request == null) return;

    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);
    final home = ModalRoute.of(context);
    // A widget tap starts over from this page: whatever the user left open
    // the last time is dropped, so repeated taps never stack pages.
    bool isHome(Route<dynamic> route) =>
        home == null ? route.isFirst : route == home;
    final l10n = AppLocalizations.of(context);
    _busy = true;
    switch ((widget.mode, request)) {
      case (
        CollectionWidgetGateMode.reject,
        OpenCollectionRequest() || QuickInputRequest(),
      ):
        // Onboarding is already on screen — that is where the tap lands.
        break;
      case (CollectionWidgetGateMode.reject, ConfigureWidgetRequest()):
        messenger.showSnackBar(
          SnackBar(content: Text(l10n.collectionWidgetNeedsSetup)),
        );
      case (
        CollectionWidgetGateMode.handle,
        OpenCollectionRequest(:final collectionId),
      ):
        final live = await widgets.isLive(collectionId);
        if (!mounted) break;
        if (live) {
          CollectionWidgetScope.collectionRouteArgs.open(collectionId);
          // Not awaited: a later tap must not wait for this page to close.
          navigator.pushAndRemoveUntil(CollectionPage.route(), isHome).ignore();
        } else {
          messenger.showSnackBar(
            SnackBar(content: Text(l10n.collectionWidgetRemoved)),
          );
        }
      case (
        CollectionWidgetGateMode.handle,
        QuickInputRequest(:final collectionId),
      ):
        final live = await widgets.isLive(collectionId);
        if (!mounted) break;
        if (live) {
          CollectionWidgetScope.collectionRouteArgs.open(
            collectionId,
            quickInput: true,
          );
          // Sent → back to the home screen; backing out stays in the app.
          navigator.pushAndRemoveUntil(CollectionPage.route(), isHome).then((
            sent,
          ) async {
            if (sent ?? false) await widgets.returnToHomeScreen();
          }).ignore();
        } else {
          messenger.showSnackBar(
            SnackBar(content: Text(l10n.collectionWidgetRemoved)),
          );
        }
      case (
        CollectionWidgetGateMode.handle,
        ConfigureWidgetRequest(:final widgetId),
      ):
        await navigator.pushAndRemoveUntil(
          CollectionWidgetPickerPage.route(
            CollectionWidgetScope.createPicker(widgetId),
          ),
          isHome,
        );
        // Picked or dismissed, the setup started on the home screen.
        await widgets.returnToHomeScreen();
    }
    _busy = false;
    // A request that arrived while this one was handled.
    if (mounted) await _handlePending();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
