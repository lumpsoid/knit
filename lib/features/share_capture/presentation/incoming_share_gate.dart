import 'package:flutter/material.dart';
import 'package:knit/features/collection/presentation/collection_page.dart';
import 'package:knit/features/share_capture/domain/share_capture_models.dart';
import 'package:knit/features/share_capture/presentation/incoming_share_controller.dart';
import 'package:knit/features/share_capture/presentation/share_capture_page.dart';
import 'package:knit/features/share_capture/presentation/share_capture_scope.dart';
import 'package:knit/l10n/app_localizations.dart';

/// What a page does with a share from another app (§4.7).
enum IncomingShareGateMode {
  /// Open the capture screen, then confirm with a "Saved — Open" snackbar.
  capture,

  /// No identity yet, so nothing can be signed: drop the share and say so.
  reject,
}

/// Wraps a root page (the Timeline, or Onboarding) and handles each pending
/// share as [mode] says. Only post-launch pages host it, so a share that
/// arrives during launch waits until the graph is up. Inert when share
/// capture isn't wired.
class IncomingShareGate extends StatefulWidget {
  const IncomingShareGate({super.key, required this.mode, required this.child});

  final IncomingShareGateMode mode;
  final Widget child;

  @override
  State<IncomingShareGate> createState() => _IncomingShareGateState();
}

class _IncomingShareGateState extends State<IncomingShareGate> {
  final IncomingShareController? _incoming = ShareCaptureScope.incoming;

  /// The capture screen is open — later shares wait until it closes.
  bool _capturing = false;

  @override
  void initState() {
    super.initState();
    _incoming?.state.addListener(_handlePending);
    WidgetsBinding.instance.addPostFrameCallback((_) => _handlePending());
  }

  @override
  void dispose() {
    _incoming?.state.removeListener(_handlePending);
    super.dispose();
  }

  Future<void> _handlePending() async {
    final incoming = _incoming;
    if (incoming == null || _capturing || !mounted) return;
    if (!incoming.state.hasPending) return;
    final items = incoming.take();
    if (items == null) return;

    final messenger = ScaffoldMessenger.of(context);
    final l10n = AppLocalizations.of(context);
    switch (widget.mode) {
      case IncomingShareGateMode.reject:
        messenger.showSnackBar(
          SnackBar(content: Text(l10n.shareCaptureNeedsSetup)),
        );
      case IncomingShareGateMode.capture:
        final navigator = Navigator.of(context);
        _capturing = true;
        final saved = await navigator.push(
          ShareCapturePage.route(ShareCaptureScope.create(items)),
        );
        _capturing = false;
        if (!mounted) return;
        if (saved != null) _confirm(messenger, navigator, l10n, saved);
        // A share that arrived while the capture screen was open.
        await _handlePending();
    }
  }

  void _confirm(
    ScaffoldMessengerState messenger,
    NavigatorState navigator,
    AppLocalizations l10n,
    ShareCaptureSaved saved,
  ) {
    messenger.showSnackBar(
      SnackBar(
        content: Text(l10n.shareCaptureSaved(saved.cardCount, saved.title)),
        action: SnackBarAction(
          label: l10n.actionOpen,
          onPressed: () {
            ShareCaptureScope.collectionRouteArgs.open(saved.collectionId);
            navigator.push(CollectionPage.route());
          },
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
