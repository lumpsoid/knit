import 'package:flutter/material.dart';
import 'package:knit/l10n/app_localizations.dart';

/// What the user chose in the reset dialog.
enum ResetIdentityChoice { backUpFirst, reset }

/// Confirms "Reset identity": the user types [word] to enable Reset, or goes to
/// back up first. Pops the choice, or null when cancelled.
class ResetIdentityDialog extends StatefulWidget {
  const ResetIdentityDialog({
    super.key,
    required this.word,
    required this.accepts,
  });

  /// The text to type, shown in the message.
  final String word;

  /// Whether the typed text confirms the reset.
  final bool Function(String typed) accepts;

  static Future<ResetIdentityChoice?> show(
    BuildContext context, {
    required String word,
    required bool Function(String typed) accepts,
  }) => showDialog<ResetIdentityChoice>(
    context: context,
    builder: (_) => ResetIdentityDialog(word: word, accepts: accepts),
  );

  @override
  State<ResetIdentityDialog> createState() => _ResetIdentityDialogState();
}

class _ResetIdentityDialogState extends State<ResetIdentityDialog> {
  final _typed = TextEditingController();

  @override
  void dispose() {
    _typed.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final confirmed = widget.accepts(_typed.text);
    return AlertDialog(
      title: Text(l10n.settingsResetConfirmTitle),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(l10n.settingsResetConfirmMessage(widget.word)),
            const SizedBox(height: 16),
            TextField(
              controller: _typed,
              autofocus: true,
              autocorrect: false,
              decoration: InputDecoration(hintText: widget.word),
              onChanged: (_) => setState(() {}),
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
          onPressed: () =>
              Navigator.of(context).pop(ResetIdentityChoice.backUpFirst),
          child: Text(l10n.settingsResetBackupFirst),
        ),
        TextButton(
          onPressed: confirmed
              ? () => Navigator.of(context).pop(ResetIdentityChoice.reset)
              : null,
          style: TextButton.styleFrom(foregroundColor: theme.colorScheme.error),
          child: Text(l10n.settingsResetConfirmAction),
        ),
      ],
    );
  }
}
