import 'package:flutter/material.dart';
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
    SyncStatusScope.controller.dispatch(const RefreshRequested());
  }

  @override
  Widget build(BuildContext context) {
    final controller = SyncStatusScope.controller;
    final scheme = Theme.of(context).colorScheme;
    return ValueListenableBuilder<SyncStatusState>(
      valueListenable: controller.stateHolder,
      builder: (context, state, _) {
        final view = syncStatusPresentation(state);
        return IconButton(
          tooltip: view.tooltip,
          onPressed: () => controller.dispatch(const RefreshRequested()),
          // Calm — onSurfaceVariant, never the error color, even on failure.
          icon: Icon(view.icon, color: scheme.onSurfaceVariant),
        );
      },
    );
  }
}

/// What the marker shows for a given [state] (§4.8). Pure + top-level so the
/// icon/tooltip mapping is unit-testable without pumping a widget. `loading`
/// reuses the last known count, so the marker doesn't flicker while refreshing.
SyncStatusPresentation syncStatusPresentation(SyncStatusState state) {
  if (state.phase == SyncStatusPhase.failed) {
    return const SyncStatusPresentation(
      icon: Icons.cloud_off_outlined,
      tooltip: 'Sync status unavailable',
    );
  }
  if (state.pendingCount == 0) {
    return const SyncStatusPresentation(
      icon: Icons.cloud_done_outlined,
      tooltip: 'All changes saved',
    );
  }
  final n = state.pendingCount;
  return SyncStatusPresentation(
    icon: Icons.save_outlined,
    tooltip: '$n ${n == 1 ? 'change' : 'changes'} '
        'saved on this device — not yet shared',
  );
}

/// The icon + tooltip the marker renders (widgets.md §1 — a widget-owned view
/// model of primitives, no feature domain type).
@immutable
class SyncStatusPresentation {
  const SyncStatusPresentation({required this.icon, required this.tooltip});
  final IconData icon;
  final String tooltip;
}
