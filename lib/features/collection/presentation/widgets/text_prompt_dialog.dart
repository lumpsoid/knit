import 'package:flutter/material.dart';
import 'package:knit/l10n/app_localizations.dart';

/// A single-field text prompt that owns its [TextEditingController], so the
/// controller is disposed when the dialog route is actually removed — disposing
/// it the moment `showDialog` returns races the route's exit animation, which
/// still rebuilds the `TextField` (TextEditingController used after dispose).
class TextPromptDialog extends StatefulWidget {
  const TextPromptDialog({
    super.key,
    required this.title,
    required this.action,
    this.hint,
  });

  final String title;
  final String action;
  final String? hint;

  @override
  State<TextPromptDialog> createState() => _TextPromptDialogState();
}

class _TextPromptDialogState extends State<TextPromptDialog> {
  final TextEditingController _field = TextEditingController();

  @override
  void dispose() {
    _field.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.title),
      content: TextField(
        controller: _field,
        autofocus: true,
        decoration: InputDecoration(hintText: widget.hint),
        onSubmitted: (v) => Navigator.of(context).pop(v),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(AppLocalizations.of(context).actionCancel),
        ),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(_field.text),
          child: Text(widget.action),
        ),
      ],
    );
  }
}
