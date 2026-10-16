import 'package:flutter/material.dart';
import 'package:knit/features/backup/domain/backup_passphrase.dart';
import 'package:knit/l10n/app_localizations.dart';

/// Asks for the passphrase that seals the keypair in a backup, typed twice.
/// Pops the passphrase, or null when dismissed.
class BackupPassphraseDialog extends StatefulWidget {
  const BackupPassphraseDialog({super.key});

  static Future<String?> show(BuildContext context) => showDialog<String>(
    context: context,
    builder: (_) => const BackupPassphraseDialog(),
  );

  @override
  State<BackupPassphraseDialog> createState() => _BackupPassphraseDialogState();
}

class _BackupPassphraseDialogState extends State<BackupPassphraseDialog> {
  static const _policy = BackupPassphrasePolicy();

  final _passphrase = TextEditingController();
  final _confirmation = TextEditingController();
  PassphraseIssue? _issue;

  @override
  void dispose() {
    _passphrase.dispose();
    _confirmation.dispose();
    super.dispose();
  }

  void _submit() {
    final issue = _policy.check(_passphrase.text, _confirmation.text);
    if (issue != null) {
      setState(() => _issue = issue);
      return;
    }
    Navigator.of(context).pop(_passphrase.text);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return AlertDialog(
      title: Text(l10n.settingsExportPassphraseTitle),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(l10n.settingsExportPassphraseMessage),
            const SizedBox(height: 16),
            TextField(
              controller: _passphrase,
              obscureText: true,
              autofocus: true,
              decoration: InputDecoration(
                labelText: l10n.settingsPassphraseLabel,
                errorText: _issue == PassphraseIssue.tooShort
                    ? l10n.settingsPassphraseTooShort(
                        BackupPassphrasePolicy.minLength,
                      )
                    : null,
              ),
              onChanged: (_) => setState(() => _issue = null),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _confirmation,
              obscureText: true,
              decoration: InputDecoration(
                labelText: l10n.settingsPassphraseConfirmLabel,
                errorText: _issue == PassphraseIssue.mismatch
                    ? l10n.settingsPassphraseMismatch
                    : null,
              ),
              onChanged: (_) => setState(() => _issue = null),
              onSubmitted: (_) => _submit(),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(l10n.actionCancel),
        ),
        TextButton(
          onPressed: _submit,
          child: Text(l10n.settingsExportPassphraseAction),
        ),
      ],
    );
  }
}
