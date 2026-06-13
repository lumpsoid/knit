import 'package:flutter/material.dart';
import 'package:knit/core/attachments/presentation/attachment_image.dart';
import 'package:knit/features/card_edit/domain/card_edit_models.dart';
import 'package:knit/features/card_edit/presentation/card_edit_action.dart';
import 'package:knit/features/card_edit/presentation/card_edit_controller.dart';
import 'package:knit/features/card_edit/presentation/card_edit_scope.dart';
import 'package:knit/features/card_edit/presentation/card_edit_state.dart';
import 'package:knit/features/card_edit/presentation/card_edit_ui_effect.dart';
import 'package:knit/features/connections/domain/connections_models.dart';

/// The Card Edit page (§4.3) — a dedicated page for editing a card's content:
/// its text (saved with the Save action), its image (subtask 4), and its links
/// (subtask 3, incl. card→card). The edit target arrives via the route-args
/// carrier (cross_feature.md §2); on text-save the page pops and the Collection
/// screen resyncs from the projection. Image/link edits are applied in place.
class CardEditPage extends StatefulWidget {
  const CardEditPage({super.key});

  static Route<void> route() =>
      MaterialPageRoute<void>(builder: (_) => const CardEditPage());

  @override
  State<CardEditPage> createState() => _CardEditPageState();
}

class _CardEditPageState extends State<CardEditPage> {
  CardEditController get _controller => CardEditScope.controller;
  late final TextEditingController _field;

  @override
  void initState() {
    super.initState();
    final args = CardEditScope.routeArgs;
    _field = TextEditingController(text: args.initialText);
    _controller
      ..onAttach(_onUiEffect)
      ..dispatch(
        ViewAttached(
          cardId: args.cardId,
          initialText: args.initialText,
          initialAttachmentId: args.initialAttachmentId,
        ),
      );
  }

  @override
  void dispose() {
    _controller
      ..dispatch(const DeactivateFeature())
      ..onDetach();
    _field.dispose();
    super.dispose();
  }

  void _onUiEffect(CardEditUiEffect effect) {
    if (!mounted) return;
    switch (effect) {
      case CardEditSavedUiEffect():
        Navigator.of(context).pop();
      case CardEditShowMessageUiEffect(:final message):
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(message)));
    }
  }

  void _save() => _controller.dispatch(SaveRequested(_field.text));

  Future<void> _addLink() async {
    final targets = _controller.stateHolder.value.targets;
    final option = await showModalBottomSheet<CardLinkOption>(
      context: context,
      isScrollControlled: true,
      builder: (_) => _LinkPickerSheet(targets: targets),
    );
    if (option == null || !mounted) return;
    _controller.dispatch(
      AddLinkRequested(targetKind: option.kind, targetId: option.id),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<CardEditState>(
      valueListenable: _controller.stateHolder,
      builder: (context, state, _) {
        final saving = state.status == CardEditStatus.saving;
        return Scaffold(
          appBar: AppBar(
            title: const Text('Edit card'),
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
                  : TextButton(
                      onPressed: _save,
                      child: const Text('Save'),
                    ),
            ],
          ),
          body: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              _ImageSection(
                state: state,
                onPick: () => _controller.dispatch(const PickImageRequested()),
                onRemove: () =>
                    _controller.dispatch(const RemoveImageRequested()),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _field,
                autofocus: true,
                enabled: !saving,
                minLines: 3,
                maxLines: null,
                keyboardType: TextInputType.multiline,
                textInputAction: TextInputAction.newline,
                decoration: const InputDecoration(
                  hintText: 'Edit this card…',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 24),
              _LinksSection(
                state: state,
                onAdd: _addLink,
                onRemove: (linkId) =>
                    _controller.dispatch(RemoveLinkRequested(linkId)),
              ),
            ],
          ),
        );
      },
    );
  }
}

// --- image section ----------------------------------------------------------

class _ImageSection extends StatelessWidget {
  const _ImageSection({
    required this.state,
    required this.onPick,
    required this.onRemove,
  });

  final CardEditState state;
  final VoidCallback onPick;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    if (state.imageBusy) {
      return const SizedBox(
        height: 160,
        child: Center(child: CircularProgressIndicator()),
      );
    }
    if (!state.hasImage) {
      return OutlinedButton.icon(
        onPressed: onPick,
        icon: const Icon(Icons.add_photo_alternate_outlined),
        label: const Text('Add photo'),
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: AttachmentImage(
            bytes: state.imageBytes,
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
              label: const Text('Replace'),
            ),
            const Spacer(),
            TextButton.icon(
              onPressed: onRemove,
              icon: Icon(
                Icons.delete_outline,
                color: Theme.of(context).colorScheme.error,
              ),
              label: Text(
                'Remove',
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

// --- links section ----------------------------------------------------------

class _LinksSection extends StatelessWidget {
  const _LinksSection({
    required this.state,
    required this.onAdd,
    required this.onRemove,
  });

  final CardEditState state;
  final VoidCallback onAdd;
  final ValueChanged<String> onRemove;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Text(
              'LINKS',
              style: theme.textTheme.labelSmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
                letterSpacing: 0.8,
              ),
            ),
            const Spacer(),
            if (state.linksLoading)
              const SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
          ],
        ),
        const SizedBox(height: 4),
        if (state.links.isEmpty && !state.linksLoading)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Text(
              'No links yet.',
              style: theme.textTheme.bodyMedium
                  ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
            ),
          ),
        for (final item in state.links)
          _LinkRow(item: item, onRemove: () => onRemove(item.linkId)),
        const SizedBox(height: 8),
        OutlinedButton.icon(
          onPressed: onAdd,
          icon: const Icon(Icons.add_link),
          label: const Text('Add link'),
        ),
      ],
    );
  }
}

/// One outgoing-link row. A live link shows the far endpoint's label + kind icon;
/// a broken one (§8.6.1) is error-styled and never hidden. Both offer remove.
class _LinkRow extends StatelessWidget {
  const _LinkRow({required this.item, required this.onRemove});

  final ConnectionItem item;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    if (item.broken) {
      return ListTile(
        contentPadding: EdgeInsets.zero,
        leading: Icon(Icons.link_off, color: theme.colorScheme.error),
        title: Text(
          'Broken link',
          style: TextStyle(color: theme.colorScheme.error),
        ),
        subtitle: const Text('The linked item was deleted'),
        trailing: IconButton(
          tooltip: 'Remove',
          icon: const Icon(Icons.close),
          onPressed: onRemove,
        ),
      );
    }
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: Icon(_kindIcon(item.otherKind)),
      title: Text(
        item.label?.trim().isNotEmpty == true ? item.label!.trim() : 'Untitled',
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      trailing: IconButton(
        tooltip: 'Remove',
        icon: const Icon(Icons.close),
        onPressed: onRemove,
      ),
    );
  }

  IconData _kindIcon(ConnectedEntityKind kind) => switch (kind) {
        ConnectedEntityKind.collection => Icons.workspaces_outline,
        ConnectedEntityKind.card => Icons.sticky_note_2_outlined,
        ConnectedEntityKind.unknown => Icons.help_outline,
      };
}

// --- link picker ------------------------------------------------------------

/// Two-level target picker (§4.3, full scope): browse collections, then drill
/// into one to pick a card — or link to the collection itself. The whole tree is
/// already in state, so the drill is local (a [StatefulBuilder]); selecting an
/// option pops it back to the page, which dispatches the add.
class _LinkPickerSheet extends StatelessWidget {
  const _LinkPickerSheet({required this.targets});

  final List<CardLinkCollectionTargets> targets;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.7,
        ),
        child: _DrilldownBody(targets: targets),
      ),
    );
  }
}

class _DrilldownBody extends StatefulWidget {
  const _DrilldownBody({required this.targets});
  final List<CardLinkCollectionTargets> targets;

  @override
  State<_DrilldownBody> createState() => _DrilldownBodyState();
}

class _DrilldownBodyState extends State<_DrilldownBody> {
  CardLinkCollectionTargets? _drilled;

  @override
  Widget build(BuildContext context) {
    final drilled = _drilled;
    if (drilled == null) return _collectionsList();
    return _cardsList(drilled);
  }

  Widget _collectionsList() {
    if (widget.targets.isEmpty) {
      return const Padding(
        padding: EdgeInsets.all(24),
        child: Text('Nothing to link to yet.'),
      );
    }
    return ListView(
      shrinkWrap: true,
      children: [
        const _SheetHeader('Link to which collection?'),
        for (final t in widget.targets)
          ListTile(
            leading: const Icon(Icons.workspaces_outline),
            title: Text(
              t.collection.label.trim().isEmpty
                  ? 'Untitled'
                  : t.collection.label.trim(),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            trailing: t.cards.isEmpty
                ? null
                : const Icon(Icons.chevron_right),
            onTap: () => setState(() => _drilled = t),
          ),
      ],
    );
  }

  Widget _cardsList(CardLinkCollectionTargets t) {
    return ListView(
      shrinkWrap: true,
      children: [
        ListTile(
          leading: const Icon(Icons.arrow_back),
          title: const Text('Back to collections'),
          onTap: () => setState(() => _drilled = null),
        ),
        const Divider(height: 1),
        // The collection itself is a valid target (card→collection).
        ListTile(
          leading: const Icon(Icons.workspaces_outline),
          title: Text(
            'Link to "${t.collection.label.trim().isEmpty ? 'Untitled' : t.collection.label.trim()}"',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          onTap: () => Navigator.of(context).pop(t.collection),
        ),
        if (t.cards.isNotEmpty) const _SheetHeader('Or a card in it'),
        for (final card in t.cards)
          ListTile(
            leading: const Icon(Icons.sticky_note_2_outlined),
            title: Text(
              card.label.trim().isEmpty ? 'Empty note' : card.label.trim(),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            onTap: () => Navigator.of(context).pop(card),
          ),
      ],
    );
  }
}

class _SheetHeader extends StatelessWidget {
  const _SheetHeader(this.label);
  final String label;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      child: Text(label, style: Theme.of(context).textTheme.titleSmall),
    );
  }
}
