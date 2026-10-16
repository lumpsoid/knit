import 'package:flutter/material.dart';
import 'package:knit/l10n/app_localizations.dart';
import 'package:knit/features/backup/domain/backup_models.dart';
import 'package:knit/features/onboard/presentation/onboard_page.dart';
import 'package:knit/features/settings/presentation/settings_action.dart';
import 'package:knit/features/settings/presentation/settings_controller.dart';
import 'package:knit/features/settings/presentation/settings_scope.dart';
import 'package:knit/features/settings/presentation/settings_state.dart';
import 'package:knit/features/settings/presentation/settings_ui_effect.dart';
import 'package:knit/features/settings/presentation/widgets/backup_passphrase_dialog.dart';
import 'package:knit/features/settings/presentation/widgets/replace_device_dialog.dart';
import 'package:knit/features/settings/presentation/widgets/reset_identity_dialog.dart';

/// The Data subpage (§4 settings): backup/transfer (export, import) and a
/// danger zone (wipe data, reset identity). A backup carries the data and the
/// keypair sealed under a passphrase, so export first asks for one, then where
/// the bundle goes. Importing another identity's bundle asks to replace this
/// device; resetting asks the user to type their nickname (or back up first)
/// and then leaves for onboarding. Every action flows through the shared
/// [SettingsScope] loop; the dialogs open on its UiEffects.
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
    final l10n = AppLocalizations.of(context);
    final text = switch (effect) {
      SettingsBackupExportedUiEffect(:final destination) =>
        destination == BackupDestination.saveFile
            ? l10n.settingsBackupSaved
            : l10n.settingsBackupExported,
      SettingsBackupImportedUiEffect(:final summary) => _importedText(
        l10n,
        summary,
      ),
      SettingsBackupFailedUiEffect(:final action) =>
        action == DataAction.importData
            ? l10n.settingsBackupImportFailed
            : l10n.settingsBackupExportFailed,
      SettingsDataWipedUiEffect() => l10n.settingsWipeDone,
      SettingsWipeFailedUiEffect() => l10n.settingsWipeFailed,
      SettingsDeviceReplacedUiEffect(:final summary) =>
        l10n.settingsDeviceReplaced(summary.opsApplied),
      SettingsResetFailedUiEffect() => l10n.settingsResetFailed,
      SettingsConfirmReplaceUiEffect() ||
      SettingsConfirmResetUiEffect() ||
      SettingsIdentityResetUiEffect() => null,
    };
    if (text != null) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
      return;
    }
    switch (effect) {
      case SettingsConfirmReplaceUiEffect(
        :final createdAtMs,
        :final wrongPassphrase,
      ):
        _askReplace(createdAtMs, wrongPassphrase);
      case SettingsConfirmResetUiEffect(:final confirmation):
        _confirmReset(confirmation.word, confirmation.accepts);
      case SettingsIdentityResetUiEffect():
        // No identity is left — start over from the onboarding ceremony.
        Navigator.of(
          context,
        ).pushAndRemoveUntil(OnboardPage.route(), (_) => false);
      default:
        break;
    }
  }

  /// The restore summary line — the counts, with a trailing warning fragment
  /// only when some ops were skipped or some blobs were corrupt.
  String _importedText(AppLocalizations l10n, ImportSummary summary) {
    final base = l10n.settingsBackupImported(
      summary.opsApplied,
      summary.opsDeduped,
    );
    if (summary.opsQuarantined == 0 && summary.blobsMismatched == 0) {
      return base;
    }
    return '$base · '
        '${l10n.settingsBackupImportWarning(summary.opsQuarantined, summary.blobsMismatched)}';
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(l10n.settingsDataTitle)),
      body: ValueListenableBuilder<SettingsState>(
        valueListenable: _controller.stateHolder,
        builder: (context, state, _) {
          return Stack(
            children: [
              _menu(context, l10n),
              // A backup is building/restoring — block the menu and spin.
              if (state.busy) const _BusyOverlay(),
            ],
          );
        },
      ),
    );
  }

  Widget _menu(BuildContext context, AppLocalizations l10n) {
    final theme = Theme.of(context);
    return ListView(
      children: [
        _SectionHeader(label: l10n.settingsDataTransferSection),
        ListTile(
          leading: const Icon(Icons.upload_file_outlined),
          title: Text(l10n.settingsExport),
          subtitle: Text(l10n.settingsExportSubtitle),
          onTap: _startExport,
        ),
        ListTile(
          leading: const Icon(Icons.download_outlined),
          title: Text(l10n.settingsImport),
          subtitle: Text(l10n.settingsImportSubtitle),
          onTap: () => _request(DataAction.importData),
        ),
        const Divider(height: 1),
        _SectionHeader(
          label: l10n.settingsDangerSection,
          color: theme.colorScheme.error,
        ),
        ListTile(
          leading: Icon(Icons.delete_outline, color: theme.colorScheme.error),
          title: Text(
            l10n.settingsWipeData,
            style: TextStyle(color: theme.colorScheme.error),
          ),
          subtitle: Text(l10n.settingsWipeDataSubtitle),
          onTap: _confirmWipe,
        ),
        ListTile(
          leading: Icon(Icons.restart_alt, color: theme.colorScheme.error),
          title: Text(
            l10n.settingsResetIdentity,
            style: TextStyle(color: theme.colorScheme.error),
          ),
          subtitle: Text(l10n.settingsResetIdentitySubtitle),
          onTap: () => _request(DataAction.resetIdentity),
        ),
      ],
    );
  }

  void _request(DataAction action) =>
      _controller.dispatch(DataActionRequested(action));

  /// Wiping is irreversible, so confirm before dispatching it. Only an explicit
  /// confirmation kicks off the (busy-spinner) wipe; dismissing does nothing.
  Future<void> _confirmWipe() async {
    final l10n = AppLocalizations.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(l10n.settingsWipeConfirmTitle),
        content: Text(l10n.settingsWipeConfirmMessage),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: Text(l10n.actionCancel),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            style: TextButton.styleFrom(
              foregroundColor: Theme.of(dialogContext).colorScheme.error,
            ),
            child: Text(l10n.settingsWipeConfirmAction),
          ),
        ],
      ),
    );
    if (confirmed == true && mounted) {
      _request(DataAction.wipeData);
    }
  }

  /// Ask for the passphrase that seals the key, then where the export should go
  /// (share sheet or a saved file), then kick off the build+deliver.
  /// Dismissing either step does nothing.
  Future<void> _startExport() async {
    final passphrase = await BackupPassphraseDialog.show(context);
    if (passphrase == null || !mounted) return;
    final l10n = AppLocalizations.of(context);
    final destination = await showModalBottomSheet<BackupDestination>(
      context: context,
      builder: (sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
              child: Align(
                alignment: AlignmentDirectional.centerStart,
                child: Text(
                  l10n.settingsExportChooseTitle,
                  style: Theme.of(sheetContext).textTheme.titleMedium,
                ),
              ),
            ),
            ListTile(
              leading: const Icon(Icons.ios_share),
              title: Text(l10n.settingsExportChooseShare),
              subtitle: Text(l10n.settingsExportChooseShareSubtitle),
              onTap: () =>
                  Navigator.of(sheetContext).pop(BackupDestination.share),
            ),
            ListTile(
              leading: const Icon(Icons.save_alt_outlined),
              title: Text(l10n.settingsExportChooseSave),
              subtitle: Text(l10n.settingsExportChooseSaveSubtitle),
              onTap: () =>
                  Navigator.of(sheetContext).pop(BackupDestination.saveFile),
            ),
          ],
        ),
      ),
    );
    if (destination != null && mounted) {
      _controller.dispatch(ExportRequested(destination, passphrase));
    }
  }

  /// The picked backup belongs to another identity: confirm erasing this device
  /// and take the backup's passphrase.
  Future<void> _askReplace(int createdAtMs, bool wrongPassphrase) async {
    final passphrase = await ReplaceDeviceDialog.show(
      context,
      createdAtMs: createdAtMs,
      wrongPassphrase: wrongPassphrase,
    );
    if (!mounted) return;
    _controller.dispatch(
      passphrase == null
          ? const ReplaceDeviceCancelled()
          : ReplaceDeviceConfirmed(passphrase),
    );
  }

  /// Resetting erases the data and the key, so the user types [word] to
  /// confirm — or backs up first, which starts the export instead.
  Future<void> _confirmReset(
    String word,
    bool Function(String typed) accepts,
  ) async {
    final choice = await ResetIdentityDialog.show(
      context,
      word: word,
      accepts: accepts,
    );
    if (!mounted) return;
    switch (choice) {
      case ResetIdentityChoice.backUpFirst:
        await _startExport();
      case ResetIdentityChoice.reset:
        _controller.dispatch(const ResetIdentityConfirmed());
      case null:
        break;
    }
  }
}

/// A blocking, semi-transparent scrim with a spinner shown while a backup is
/// building or restoring — it both signals progress and swallows taps so the
/// menu can't be re-triggered mid-run.
class _BusyOverlay extends StatelessWidget {
  const _BusyOverlay();

  @override
  Widget build(BuildContext context) {
    return const Positioned.fill(
      child: AbsorbPointer(
        child: ColoredBox(
          color: Color(0x66000000),
          child: Center(child: CircularProgressIndicator()),
        ),
      ),
    );
  }
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
