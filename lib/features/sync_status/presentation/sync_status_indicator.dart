import 'package:flutter/material.dart';
import 'package:knit/l10n/app_localizations.dart';
import 'package:knit/features/sync_status/presentation/sync_status_action.dart';
import 'package:knit/features/sync_status/presentation/sync_status_scope.dart';
import 'package:knit/features/sync_status/presentation/sync_status_state.dart';

/// The app-wide sync marker (§4.8 / §6.6): a small, calm app-bar action showing
/// whether local changes are saved. Drop `const SyncStatusIndicator()` into a
/// page's `AppBar.actions`; it resolves the app-wide [SyncStatusScope]
/// controller and refreshes the count when the page mounts it.
///
/// Relay-less today: nothing ever acks (§6.6), so the count only grows — the
/// marker reads as "saved on this device", never an alarm. A reactive,
/// push-on-change refresh arrives with the relay via the ExternalSignalListener
/// seam (cross_feature §1); until then it refreshes on mount (and on tap).
class SyncStatusIndicator extends StatefulWidget {
  const SyncStatusIndicator({super.key});

  @override
  State<SyncStatusIndicator> createState() => _SyncStatusIndicatorState();
}

class _SyncStatusIndicatorState extends State<SyncStatusIndicator> {
  @override
  void initState() {
    super.initState();
    // Refresh on mount — but never synchronously during build. The controller
    // is app-wide and shared across every page's marker, and dispatch updates
    // its ValueNotifier synchronously; a bare dispatch here would notify
    // another page's already-mounted marker mid-build (setState/markNeedsBuild
    // called during build). Defer past the current frame.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) SyncStatusScope.controller.dispatch(const RefreshRequested());
    });
  }

  @override
  Widget build(BuildContext context) {
    final controller = SyncStatusScope.controller;
    final scheme = Theme.of(context).colorScheme;
    final l10n = AppLocalizations.of(context);
    return ValueListenableBuilder<SyncStatusState>(
      valueListenable: controller.stateHolder,
      builder: (context, state, _) {
        final view = syncStatusPresentation(state);
        final tooltip = switch (view.label) {
          SyncStatusLabel.allSaved => l10n.syncAllSaved,
          SyncStatusLabel.unavailable => l10n.syncUnavailable,
          SyncStatusLabel.pending => l10n.syncPending(view.pendingCount),
        };
        return IconButton(
          tooltip: tooltip,
          onPressed: () => controller.dispatch(const RefreshRequested()),
          // Calm — onSurfaceVariant, never the error color, even on failure.
          icon: Icon(view.icon, color: scheme.onSurfaceVariant),
        );
      },
    );
  }
}

/// The semantic tooltip the marker shows (§4.8) — mapped to localized text by
/// the widget. Locale-independent so the mapping stays unit-testable.
enum SyncStatusLabel { allSaved, pending, unavailable }

/// What the marker shows for a given [state] (§4.8). Pure + top-level so the
/// icon/label mapping is unit-testable without pumping a widget. `loading`
/// reuses the last known count, so the marker doesn't flicker while refreshing.
SyncStatusPresentation syncStatusPresentation(SyncStatusState state) {
  if (state.phase == SyncStatusPhase.failed) {
    return const SyncStatusPresentation(
      icon: Icons.cloud_off_outlined,
      label: SyncStatusLabel.unavailable,
    );
  }
  if (state.pendingCount == 0) {
    return const SyncStatusPresentation(
      icon: Icons.cloud_done_outlined,
      label: SyncStatusLabel.allSaved,
    );
  }
  // Cloud-themed like the other two states (cloud_done / cloud_off) so the
  // marker reads as a sync/share status, never a "tap to save" disk affordance:
  // these changes are already saved locally, just not yet shared (§6.6).
  return SyncStatusPresentation(
    icon: Icons.cloud_upload_outlined,
    label: SyncStatusLabel.pending,
    pendingCount: state.pendingCount,
  );
}

/// The icon + semantic label the marker renders (widgets.md §1 — a widget-owned
/// view model of primitives, no feature domain type). [pendingCount] backs the
/// localized plural for [SyncStatusLabel.pending].
@immutable
class SyncStatusPresentation {
  const SyncStatusPresentation({
    required this.icon,
    required this.label,
    this.pendingCount = 0,
  });
  final IconData icon;
  final SyncStatusLabel label;
  final int pendingCount;
}
