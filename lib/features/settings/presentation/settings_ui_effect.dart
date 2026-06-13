import 'package:knit/features/settings/presentation/settings_action.dart';

/// One-shot UI effects the shell pushes for the Settings views (fcis.md §6.4).
sealed class SettingsUiEffect {
  const SettingsUiEffect();
}

/// Announce that a data-management action isn't implemented yet — the Data page
/// maps the [DataAction] to a localized label and shows a "coming soon" snackbar
/// without the shell touching `BuildContext` or l10n.
class SettingsComingSoonUiEffect extends SettingsUiEffect {
  const SettingsComingSoonUiEffect(this.action);
  final DataAction action;
}
