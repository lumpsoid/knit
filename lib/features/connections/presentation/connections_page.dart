import 'package:flutter/material.dart';
import 'package:knit/features/connections/domain/connections_models.dart';
import 'package:knit/features/connections/presentation/connections_action.dart';
import 'package:knit/features/connections/presentation/connections_controller.dart';
import 'package:knit/features/connections/presentation/connections_scope.dart';
import 'package:knit/features/connections/presentation/connections_state.dart';
import 'package:knit/features/connections/presentation/connections_ui_effect.dart';

/// The Connections view (§4.4) — an entity's links-out + linked-from
/// (backlinks), each live one tappable to jump (pushing a breadcrumb), each
/// broken one rendered as a §8.6.1 chip that offers "clear" but never vanishes.
class ConnectionsPage extends StatefulWidget {
  const ConnectionsPage({super.key});

  static Route<void> route() =>
      MaterialPageRoute<void>(builder: (_) => const ConnectionsPage());

  @override
  State<ConnectionsPage> createState() => _ConnectionsPageState();
}

class _ConnectionsPageState extends State<ConnectionsPage> {
  ConnectionsController get _controller => ConnectionsScope.controller;

  @override
  void initState() {
    super.initState();
    final args = ConnectionsScope.routeArgs;
    _controller
      ..onAttach(_onUiEffect)
      ..dispatch(
        ViewAttached(
          kind: args.entityKind,
          id: args.entityId,
          title: args.entityTitle,
        ),
      );
  }

  @override
  void dispose() {
    _controller
      ..dispatch(const DeactivateFeature())
      ..onDetach();
    super.dispose();
  }

  void _onUiEffect(ConnectionsUiEffect effect) {
    if (!mounted) return;
    switch (effect) {
      case ConnectionsShowMessageUiEffect(:final message):
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(message)));
    }
  }

  Future<void> _confirmClear(ConnectionItem item) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Clear this link?'),
        content: const Text(
          'The broken link will be removed. The cards and collections it '
          'pointed at are not deleted.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Clear'),
          ),
        ],
      ),
    );
    if (ok == true && mounted) {
      _controller.dispatch(ClearLinkRequested(item.linkId));
    }
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<ConnectionsState>(
      valueListenable: _controller.stateHolder,
      builder: (context, state, _) {
        return PopScope(
          // At the root, let the route pop (leave the feature); deeper in, the
          // back gesture pops one breadcrumb hop instead (§4.4).
          canPop: state.atRoot,
          onPopInvokedWithResult: (didPop, _) {
            if (!didPop) _controller.dispatch(const BackRequested());
          },
          child: Scaffold(
            appBar: AppBar(
              title: Text(_focusTitle(state)),
              bottom: state.breadcrumb.length > 1
                  ? _Breadcrumb(
                      crumbs: state.breadcrumb,
                      onTap: (i) => _controller.dispatch(CrumbTapped(i)),
                    )
                  : null,
            ),
            body: _body(state),
          ),
        );
      },
    );
  }

  String _focusTitle(ConnectionsState state) {
    if (state.breadcrumb.isEmpty) return 'Connections';
    final title = state.breadcrumb.last.title.trim();
    return title.isEmpty ? 'Connections' : title;
  }

  Widget _body(ConnectionsState state) {
    switch (state.status) {
      case ConnectionsStatus.loading:
        if (state.data == null) {
          return const Center(child: CircularProgressIndicator());
        }
        return _list(state);
      case ConnectionsStatus.failed:
        return _ErrorView(
          message: state.errorMessage ?? 'Something went wrong',
          onRetry: () => _controller.dispatch(const ReloadRequested()),
        );
      case ConnectionsStatus.ready:
        if (state.isEmpty) return const _EmptyView();
        return _list(state);
    }
  }

  Widget _list(ConnectionsState state) {
    final data = state.data!;
    return RefreshIndicator(
      onRefresh: () async => _controller.dispatch(const ReloadRequested()),
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.symmetric(vertical: 8),
        children: [
          if (data.outgoing.isNotEmpty) ...[
            const _SectionHeader('Links out'),
            for (final item in data.outgoing)
              _ConnectionTile(
                item: item,
                onJump: () => _controller.dispatch(ConnectionTapped(item)),
                onClear: () => _confirmClear(item),
              ),
          ],
          if (data.incoming.isNotEmpty) ...[
            const _SectionHeader('Linked from'),
            for (final item in data.incoming)
              _ConnectionTile(
                item: item,
                onJump: () => _controller.dispatch(ConnectionTapped(item)),
                onClear: () => _confirmClear(item),
              ),
          ],
        ],
      ),
    );
  }
}

// --- widgets ---------------------------------------------------------------

class _Breadcrumb extends StatelessWidget implements PreferredSizeWidget {
  const _Breadcrumb({required this.crumbs, required this.onTap});
  final List<ConnectionCrumb> crumbs;
  final ValueChanged<int> onTap;

  @override
  Size get preferredSize => const Size.fromHeight(36);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SizedBox(
      height: 36,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        itemCount: crumbs.length,
        itemBuilder: (context, i) {
          final crumb = crumbs[i];
          final isLast = i == crumbs.length - 1;
          final label = crumb.title.trim().isEmpty ? '…' : crumb.title.trim();
          return Row(
            children: [
              if (i > 0)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 2),
                  child: Icon(
                    Icons.chevron_right,
                    size: 16,
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              InkWell(
                onTap: isLast ? null : () => onTap(i),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 4,
                    vertical: 6,
                  ),
                  child: Text(
                    label,
                    style: theme.textTheme.bodySmall?.copyWith(
                      fontWeight: isLast ? FontWeight.w700 : FontWeight.w400,
                      color: isLast
                          ? theme.colorScheme.onSurface
                          : theme.colorScheme.primary,
                    ),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader(this.label);
  final String label;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
      child: Text(
        label.toUpperCase(),
        style: theme.textTheme.labelSmall?.copyWith(
          color: theme.colorScheme.onSurfaceVariant,
          letterSpacing: 0.8,
        ),
      ),
    );
  }
}

/// One connection row. A live one is a tappable tile that jumps; a broken one is
/// the §8.6.1 chip — error-styled, not tappable, with a "Clear" affordance.
class _ConnectionTile extends StatelessWidget {
  const _ConnectionTile({
    required this.item,
    required this.onJump,
    required this.onClear,
  });

  final ConnectionItem item;
  final VoidCallback onJump;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    if (item.broken) {
      return ListTile(
        leading: Icon(Icons.link_off, color: theme.colorScheme.error),
        title: Text(
          'Broken link',
          style: TextStyle(color: theme.colorScheme.error),
        ),
        subtitle: Text(_brokenSubtitle()),
        trailing: TextButton(onPressed: onClear, child: const Text('Clear')),
      );
    }
    return ListTile(
      leading: Icon(_kindIcon(item.otherKind)),
      title: Text(
        item.label?.trim().isNotEmpty == true ? item.label!.trim() : 'Untitled',
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      trailing: const Icon(Icons.chevron_right),
      onTap: onJump,
    );
  }

  String _brokenSubtitle() {
    final kind = switch (item.otherKind) {
      ConnectedEntityKind.collection => 'collection',
      ConnectedEntityKind.card => 'card',
      ConnectedEntityKind.unknown => 'item',
    };
    return item.direction == ConnectionDirection.outgoing
        ? 'The linked $kind was deleted'
        : 'The linking $kind was deleted';
  }

  IconData _kindIcon(ConnectedEntityKind kind) => switch (kind) {
        ConnectedEntityKind.collection => Icons.workspaces_outline,
        ConnectedEntityKind.card => Icons.sticky_note_2_outlined,
        ConnectedEntityKind.unknown => Icons.help_outline,
      };
}

class _EmptyView extends StatelessWidget {
  const _EmptyView();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.hub_outlined,
                size: 64, color: theme.colorScheme.primary),
            const SizedBox(height: 16),
            Text('No connections yet',
                style: theme.textTheme.titleMedium
                    ?.copyWith(fontWeight: FontWeight.w700)),
            const SizedBox(height: 8),
            Text(
              'Link a card to a collection and it will show up here.',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium
                  ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
            ),
          ],
        ),
      ),
    );
  }
}

class _ErrorView extends StatelessWidget {
  const _ErrorView({required this.message, required this.onRetry});
  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.error_outline, size: 48, color: theme.colorScheme.error),
            const SizedBox(height: 16),
            Text(message,
                textAlign: TextAlign.center,
                style: theme.textTheme.bodyMedium),
            const SizedBox(height: 24),
            FilledButton(onPressed: onRetry, child: const Text('Retry')),
          ],
        ),
      ),
    );
  }
}
