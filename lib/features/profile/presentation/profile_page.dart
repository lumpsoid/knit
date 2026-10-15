import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:knit/l10n/app_localizations.dart';
import 'package:knit/features/profile/domain/profile_view.dart';
import 'package:knit/features/profile/presentation/profile_action.dart';
import 'package:knit/features/profile/presentation/profile_controller.dart';
import 'package:knit/features/profile/presentation/profile_scope.dart';
import 'package:knit/features/profile/presentation/profile_state.dart';
import 'package:knit/features/profile/presentation/profile_ui_effect.dart';

/// The Profile / identity screen (spec §5/§7.4.7): the device's handle, an
/// editable nickname ("you can change it anytime"), and the full public key —
/// the real identity — with copy. Reached from the Timeline app bar.
class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key});

  static Route<void> route() =>
      MaterialPageRoute<void>(builder: (_) => const ProfilePage());

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  ProfileController get _controller => ProfileScope.controller;

  @override
  void initState() {
    super.initState();
    _controller
      ..onAttach(_onUiEffect)
      ..dispatch(const ViewAttached());
  }

  @override
  void dispose() {
    _controller
      ..dispatch(const DeactivateFeature())
      ..onDetach();
    super.dispose();
  }

  void _onUiEffect(ProfileUiEffect effect) {
    if (!mounted) return;
    switch (effect) {
      case ProfileShowMessageUiEffect(:final message):
        final l10n = AppLocalizations.of(context);
        final text = switch (message) {
          ProfileMessage.renameFailed => l10n.profileRenameFailed,
        };
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(text)));
    }
  }

  Future<void> _editNickname(ProfileView profile) async {
    final nickname = await showDialog<String>(
      context: context,
      builder: (_) => _RenameDialog(initial: profile.nickname),
    );
    if (nickname == null || nickname.trim().isEmpty || !mounted) return;
    if (nickname.trim() == profile.nickname) return;
    _controller.dispatch(RenameRequested(nickname.trim()));
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(l10n.profileTitle)),
      body: ValueListenableBuilder<ProfileState>(
        valueListenable: _controller.stateHolder,
        builder: (context, state, _) {
          final profile = state.profile;
          switch (state.phase) {
            case ProfilePhase.loading:
              if (profile == null) {
                return const Center(child: CircularProgressIndicator());
              }
              return _body(state, profile);
            case ProfilePhase.failed:
              return _ErrorView(
                message: l10n.profileLoadError,
                onRetry: () => _controller.dispatch(const RefreshRequested()),
              );
            case ProfilePhase.ready:
              if (profile == null) {
                return const Center(child: CircularProgressIndicator());
              }
              return _body(state, profile);
          }
        },
      ),
    );
  }

  Widget _body(ProfileState state, ProfileView profile) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);
    return RefreshIndicator(
      onRefresh: () async => _controller.dispatch(const RefreshRequested()),
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(24, 24, 24, 24),
        children: [
          Center(
            child: Column(
              children: [
                CircleAvatar(
                  radius: 44,
                  backgroundColor: _avatarColor(profile.fingerprint),
                  child: Text(
                    profile.nickname.isEmpty
                        ? '?'
                        : profile.nickname.substring(0, 1).toUpperCase(),
                    style: theme.textTheme.headlineMedium?.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  profile.handle,
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 32),
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.badge_outlined),
            title: Text(
              l10n.profileNicknameLabel,
              style: theme.textTheme.labelMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            subtitle: Text(
              profile.nickname.isEmpty ? l10n.labelUntitled : profile.nickname,
              style: theme.textTheme.bodyLarge,
            ),
            trailing: state.isSaving
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : IconButton(
                    tooltip: l10n.profileEditNickname,
                    icon: const Icon(Icons.edit_outlined),
                    onPressed: () => _editNickname(profile),
                  ),
          ),
          const Divider(height: 32),
          Row(
            children: [
              Icon(
                Icons.key_outlined,
                size: 18,
                color: theme.colorScheme.onSurfaceVariant,
              ),
              const SizedBox(width: 8),
              Text(
                l10n.profilePublicKeyLabel,
                style: theme.textTheme.labelMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          _PubkeyBox(publicKeyHex: profile.publicKeyHex),
        ],
      ),
    );
  }

  /// Deterministic avatar hue from the fingerprint (§5) — same key, same color.
  Color _avatarColor(String fingerprint) {
    final v = int.tryParse(fingerprint, radix: 16) ?? 0;
    return HSLColor.fromAHSL(1, (v % 360).toDouble(), 0.55, 0.5).toColor();
  }
}

/// The "edit nickname" prompt. Owns its [TextEditingController] so it's disposed
/// only when the dialog route is removed (disposing on `showDialog` return races
/// the exit animation, which still rebuilds the `TextField`).
class _RenameDialog extends StatefulWidget {
  const _RenameDialog({required this.initial});
  final String initial;

  @override
  State<_RenameDialog> createState() => _RenameDialogState();
}

class _RenameDialogState extends State<_RenameDialog> {
  late final TextEditingController _field = TextEditingController(
    text: widget.initial,
  );

  @override
  void dispose() {
    _field.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return AlertDialog(
      title: Text(l10n.profileRenameTitle),
      content: TextField(
        controller: _field,
        autofocus: true,
        decoration: InputDecoration(hintText: l10n.profileRenameHint),
        onSubmitted: (v) => Navigator.of(context).pop(v),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(l10n.actionCancel),
        ),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(_field.text),
          child: Text(l10n.actionSave),
        ),
      ],
    );
  }
}

class _PubkeyBox extends StatelessWidget {
  const _PubkeyBox({required this.publicKeyHex});
  final String publicKeyHex;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Expanded(
            child: SelectableText(
              publicKeyHex,
              maxLines: 2,
              style: const TextStyle(
                fontFamily: 'monospace',
                fontSize: 12,
                height: 1.4,
              ),
            ),
          ),
          IconButton(
            tooltip: l10n.profileCopyKey,
            icon: const Icon(Icons.copy, size: 18),
            onPressed: () {
              Clipboard.setData(ClipboardData(text: publicKeyHex));
              ScaffoldMessenger.of(
                context,
              ).showSnackBar(SnackBar(content: Text(l10n.profileKeyCopied)));
            },
          ),
        ],
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
            Text(
              message,
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium,
            ),
            const SizedBox(height: 24),
            FilledButton(
              onPressed: onRetry,
              child: Text(AppLocalizations.of(context).actionRetry),
            ),
          ],
        ),
      ),
    );
  }
}
