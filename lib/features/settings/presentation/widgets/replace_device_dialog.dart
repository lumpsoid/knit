import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:knit/l10n/app_localizations.dart';

/// Confirms replacing this device with a backup from another identity and asks
/// for the backup's passphrase. Pops the passphrase, or null when cancelled.
class ReplaceDeviceDialog extends StatefulWidget {
  const ReplaceDeviceDialog({
    super.key,
    required this.createdAtMs,
    required this.wrongPassphrase,
  });

  final int createdAtMs;
  final bool wrongPassphrase;

  static Future<String?> show(
    BuildContext context, {
    required int createdAtMs,
    required bool wrongPassphrase,
  }) => showDialog<String>(
    context: context,
    barrierDismissible: false,
    builder: (_) => ReplaceDeviceDialog(
      createdAtMs: createdAtMs,
      wrongPassphrase: wrongPassphrase,
    ),
  );

  @override
  State<ReplaceDeviceDialog> createState() => _ReplaceDeviceDialogState();
}

class _ReplaceDeviceDialogState extends State<ReplaceDeviceDialog> {
  final _passphrase = TextEditingController();

  @override
  void dispose() {
    _passphrase.dispose();
    super.dispose();
  }

  void _submit() {
    if (_passphrase.text.isEmpty) return;
    Navigator.of(context).pop(_passphrase.text);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final date = DateFormat.yMMMd(
      Localizations.localeOf(context).toString(),
    ).format(DateTime.fromMillisecondsSinceEpoch(widget.createdAtMs));
    return AlertDialog(
      title: Text(l10n.settingsReplaceTitle),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(l10n.settingsReplaceMessage(date)),
            const SizedBox(height: 16),
            TextField(
              controller: _passphrase,
              obscureText: true,
              autofocus: true,
              decoration: InputDecoration(
                labelText: l10n.settingsPassphraseLabel,
                errorText: widget.wrongPassphrase
                    ? l10n.settingsReplaceWrongPassphrase
                    : null,
              ),
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
          style: TextButton.styleFrom(foregroundColor: theme.colorScheme.error),
          child: Text(l10n.settingsReplaceAction),
        ),
      ],
    );
  }
}
