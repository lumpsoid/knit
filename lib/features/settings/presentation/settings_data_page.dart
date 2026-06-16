import 'package:flutter/material.dart';
import 'package:knit/l10n/app_localizations.dart';
import 'package:knit/features/settings/presentation/settings_action.dart';
import 'package:knit/features/settings/presentation/settings_controller.dart';
import 'package:knit/features/settings/presentation/settings_scope.dart';
import 'package:knit/features/settings/presentation/settings_ui_effect.dart';

/// The Data subpage (§4 settings): backup/transfer (export, import, export
/// identity) and a danger zone (wipe data, reset identity). Every action flows
/// through the shared [SettingsScope] loop as a [DataActionRequested]; today the
/// shell answers with a "coming soon" UiEffect this page shows as a snackbar.
class SettingsDataPage extends StatefulWidget {
  const SettingsDataPage({super.key});

  static Route<void> route() =>
      MaterialPageRoute<void>(builder: (_) => const SettingsDataPage());

  @override
  State<SettingsDataPage> createState() => _SettingsDataPageState();
}

class _SettingsDataPageState extends State<SettingsDataPage> {
  SettingsController get _controller => SettingsScope.controller;

  @override
  void initState() {
    super.initState();
    _controller.onAttach(_onUiEffect);
  }

  @override
  void dispose() {
    _controller.onDetach();
    super.dispose();
  }

  void _onUiEffect(SettingsUiEffect effect) {
    if (!mounted) return;
    switch (effect) {
      case SettingsComingSoonUiEffect(:final action):
        final l10n = AppLocalizations.of(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10n.settingsComingSoon(_label(l10n, action)))),
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);
    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.settingsDataTitle),
      ),
      body: ListView(
        children: [
          _SectionHeader(label: l10n.settingsDataTransferSection),
          ListTile(
            leading: const Icon(Icons.upload_file_outlined),
            title: Text(l10n.settingsExport),
            subtitle: Text(l10n.settingsExportSubtitle),
            onTap: () => _request(DataAction.exportData),
          ),
          ListTile(
            leading: const Icon(Icons.download_outlined),
            title: Text(l10n.settingsImport),
            subtitle: Text(l10n.settingsImportSubtitle),
            onTap: () => _request(DataAction.importData),
          ),
          ListTile(
            leading: const Icon(Icons.key_outlined),
            title: Text(l10n.settingsExportIdentity),
            subtitle: Text(l10n.settingsExportIdentitySubtitle),
            onTap: () => _request(DataAction.exportIdentity),
          ),
          const Divider(height: 1),
          _SectionHeader(
            label: l10n.settingsDangerSection,
            color: theme.colorScheme.error,
          ),
          ListTile(
            leading: Icon(Icons.delete_outline, color: theme.colorScheme.error),
            title: Text(l10n.settingsWipeData,
                style: TextStyle(color: theme.colorScheme.error)),
            subtitle: Text(l10n.settingsWipeDataSubtitle),
            onTap: () => _request(DataAction.wipeData),
          ),
          ListTile(
            leading: Icon(Icons.restart_alt, color: theme.colorScheme.error),
            title: Text(l10n.settingsResetIdentity,
                style: TextStyle(color: theme.colorScheme.error)),
            subtitle: Text(l10n.settingsResetIdentitySubtitle),
            onTap: () => _request(DataAction.resetIdentity),
          ),
        ],
      ),
    );
  }

  void _request(DataAction action) =>
      _controller.dispatch(DataActionRequested(action));

  String _label(AppLocalizations l10n, DataAction action) => switch (action) {
        DataAction.exportData => l10n.settingsExport,
        DataAction.importData => l10n.settingsImport,
        DataAction.exportIdentity => l10n.settingsExportIdentity,
        DataAction.wipeData => l10n.settingsWipeData,
        DataAction.resetIdentity => l10n.settingsResetIdentity,
      };
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.label, this.color});
  final String label;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 8),
      child: Text(
        label.toUpperCase(),
        style: theme.textTheme.labelMedium?.copyWith(
          color: color ?? theme.colorScheme.primary,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.5,
        ),
      ),
    );
  }
}
