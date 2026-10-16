import 'package:flutter/material.dart';
import 'package:knit/features/collection_widget/domain/collection_widget_models.dart';
import 'package:knit/features/collection_widget/presentation/collection_widget_picker_controller.dart';
import 'package:knit/features/collection_widget/presentation/collection_widget_picker_state.dart';
import 'package:knit/l10n/app_localizations.dart';

/// Picks the collection a home-screen widget opens. Pops with true once the
/// widget is bound, or null when dismissed. Takes ownership of [controller]
/// and disposes it with the page.
class CollectionWidgetPickerPage extends StatefulWidget {
  const CollectionWidgetPickerPage({super.key, required this.controller});

  final CollectionWidgetPickerController controller;

  static Route<bool> route(CollectionWidgetPickerController controller) =>
      MaterialPageRoute<bool>(
        fullscreenDialog: true,
        builder: (_) => CollectionWidgetPickerPage(controller: controller),
      );

  @override
  State<CollectionWidgetPickerPage> createState() =>
      _CollectionWidgetPickerPageState();
}

class _CollectionWidgetPickerPageState
    extends State<CollectionWidgetPickerPage> {
  CollectionWidgetPickerController get _controller => widget.controller;

  @override
  void initState() {
    super.initState();
    _controller.load();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _choose(CollectionWidgetTarget target) async {
    final bound = await _controller.choose(target);
    if (!mounted) return;
    if (bound) {
      Navigator.of(context).pop(true);
      return;
    }
    if (_controller.state.saveFailed) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(AppLocalizations.of(context).collectionWidgetSaveError),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return ListenableBuilder(
      listenable: _controller.state,
      builder: (context, _) {
        final state = _controller.state;
        return Scaffold(
          appBar: AppBar(
            leading: IconButton(
              tooltip: l10n.actionCancel,
              icon: const Icon(Icons.close),
              onPressed: () => Navigator.of(context).pop(),
            ),
            title: Text(l10n.collectionWidgetPickTitle),
            bottom: state.saving
                ? const PreferredSize(
                    preferredSize: Size.fromHeight(4),
                    child: LinearProgressIndicator(),
                  )
                : null,
          ),
          body: AbsorbPointer(
            absorbing: state.saving,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                  child: TextField(
                    onChanged: _controller.filter,
                    textInputAction: TextInputAction.search,
                    decoration: InputDecoration(
                      prefixIcon: const Icon(Icons.search),
                      hintText: l10n.shareCaptureSearchHint,
                      border: const OutlineInputBorder(),
                      isDense: true,
                    ),
                  ),
                ),
                const Divider(height: 1),
                Expanded(child: _targets(l10n, state)),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _targets(AppLocalizations l10n, CollectionWidgetPickerState state) {
    switch (state.status) {
      case CollectionWidgetPickerStatus.loading:
        return const Center(child: CircularProgressIndicator());
      case CollectionWidgetPickerStatus.failed:
        return Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(l10n.shareCaptureLoadError),
              const SizedBox(height: 12),
              FilledButton(
                onPressed: _controller.load,
                child: Text(l10n.actionRetry),
              ),
            ],
          ),
        );
      case CollectionWidgetPickerStatus.ready:
        final targets = state.visibleTargets;
        if (targets.isEmpty) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Text(
                state.targets.isEmpty
                    ? l10n.collectionWidgetEmpty
                    : l10n.shareCaptureNoMatches,
                textAlign: TextAlign.center,
              ),
            ),
          );
        }
        return ListView.builder(
          itemCount: targets.length,
          itemBuilder: (context, i) {
            final target = targets[i];
            return ListTile(
              leading: const Icon(Icons.collections_bookmark_outlined),
              title: Text(
                target.title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              onTap: () => _choose(target),
            );
          },
        );
    }
  }
}
