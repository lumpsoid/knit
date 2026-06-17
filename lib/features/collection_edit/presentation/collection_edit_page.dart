import 'package:flutter/material.dart';
import 'package:knit/l10n/app_localizations.dart';
import 'package:knit/core/attachments/presentation/attachment_image.dart';
import 'package:knit/features/collection_edit/presentation/collection_edit_action.dart';
import 'package:knit/features/collection_edit/presentation/collection_edit_controller.dart';
import 'package:knit/features/collection_edit/presentation/collection_edit_scope.dart';
import 'package:knit/features/collection_edit/presentation/collection_edit_state.dart';
import 'package:knit/features/collection_edit/presentation/collection_edit_ui_effect.dart';

/// The Collection Edit page (§4.2/§4.3) — a dedicated page for editing a
/// collection's title, description, and cover image. The edit target arrives via
/// the route-args carrier (cross_feature.md §2); on save the page pops and the
/// Collection screen resyncs from the projection. Cover edits are applied in
/// place.
class CollectionEditPage extends StatefulWidget {
  const CollectionEditPage({super.key});

  static Route<void> route() =>
      MaterialPageRoute<void>(builder: (_) => const CollectionEditPage());

  @override
  State<CollectionEditPage> createState() => _CollectionEditPageState();
}

class _CollectionEditPageState extends State<CollectionEditPage> {
  CollectionEditController get _controller => CollectionEditScope.controller;
  late final TextEditingController _title;
  late final TextEditingController _description;

  @override
  void initState() {
    super.initState();
    final args = CollectionEditScope.routeArgs;
    _title = TextEditingController(text: args.initialTitle);
    _description = TextEditingController(text: args.initialDescription ?? '');
    _controller
      ..onAttach(_onUiEffect)
      ..dispatch(
        ViewAttached(
          collectionId: args.collectionId,
          initialTitle: args.initialTitle,
          initialDescription: args.initialDescription,
          initialCoverAttachmentId: args.initialCoverAttachmentId,
        ),
      );
  }

  @override
  void dispose() {
    _controller
      ..dispatch(const DeactivateFeature())
      ..onDetach();
    _title.dispose();
    _description.dispose();
    super.dispose();
  }

  void _onUiEffect(CollectionEditUiEffect effect) {
    if (!mounted) return;
    switch (effect) {
      case CollectionEditSavedUiEffect():
        Navigator.of(context).pop();
      case CollectionEditShowMessageUiEffect(:final message):
        final text = switch (message) {
          CollectionEditMessage.saveFailed => AppLocalizations.of(
            context,
          ).collectionSaveFailed,
        };
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(text)));
    }
  }

  void _save() => _controller.dispatch(
    SaveRequested(title: _title.text, description: _description.text),
  );

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return ValueListenableBuilder<CollectionEditState>(
      valueListenable: _controller.stateHolder,
      builder: (context, state, _) {
        final saving = state.status == CollectionEditStatus.saving;
        return Scaffold(
          appBar: AppBar(
            title: Text(l10n.collectionEditTitle),
            actions: [
              saving
                  ? const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 16),
                      child: Center(
                        child: SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                      ),
                    )
                  : TextButton(onPressed: _save, child: Text(l10n.actionSave)),
            ],
          ),
          body: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              _CoverSection(
                state: state,
                onPick: () => _controller.dispatch(const PickCoverRequested()),
                onRemove: () =>
                    _controller.dispatch(const RemoveCoverRequested()),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _title,
                autofocus: true,
                enabled: !saving,
                textInputAction: TextInputAction.next,
                textCapitalization: TextCapitalization.sentences,
                decoration: InputDecoration(
                  labelText: l10n.collectionEditTitleHint,
                  border: const OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _description,
                enabled: !saving,
                minLines: 3,
                maxLines: null,
                keyboardType: TextInputType.multiline,
                textCapitalization: TextCapitalization.sentences,
                decoration: InputDecoration(
                  labelText: l10n.collectionEditDescriptionHint,
                  alignLabelWithHint: true,
                  border: const OutlineInputBorder(),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

/// The collection's cover-image manager (§4.2). With no cover it offers a single
/// add (a photo); with one it shows the image over Replace + Remove. A collection
/// has no audio/file media (spec §3.1), so the cover is image-only.
class _CoverSection extends StatelessWidget {
  const _CoverSection({
    required this.state,
    required this.onPick,
    required this.onRemove,
  });

  final CollectionEditState state;
  final VoidCallback onPick;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    if (state.coverBusy) {
      return const SizedBox(
        height: 160,
        child: Center(child: CircularProgressIndicator()),
      );
    }
    if (!state.hasCover) {
      return OutlinedButton.icon(
        onPressed: onPick,
        icon: const Icon(Icons.add_photo_alternate_outlined),
        label: Text(l10n.collectionEditAddCover),
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: AttachmentImage(
            bytes: state.coverBytes,
            height: 220,
            fit: BoxFit.cover,
          ),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            TextButton.icon(
              onPressed: onPick,
              icon: const Icon(Icons.swap_horiz),
              label: Text(l10n.collectionEditReplaceCover),
            ),
            const Spacer(),
            TextButton.icon(
              onPressed: onRemove,
              icon: Icon(
                Icons.delete_outline,
                color: Theme.of(context).colorScheme.error,
              ),
              label: Text(
                l10n.collectionEditRemoveCover,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            ),
          ],
        ),
      ],
    );
  }
}
