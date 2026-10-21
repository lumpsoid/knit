import 'package:flutter/material.dart';
import 'package:knit/l10n/app_localizations.dart';
import 'package:knit/features/settings/domain/app_preferences.dart';
import 'package:knit/features/settings/presentation/settings_about_page.dart';
import 'package:knit/features/settings/presentation/settings_action.dart';
import 'package:knit/features/settings/presentation/settings_controller.dart';
import 'package:knit/features/settings/presentation/settings_data_page.dart';
import 'package:knit/features/settings/presentation/settings_scope.dart';
import 'package:knit/features/settings/presentation/settings_state.dart';

/// The Settings home (§4 settings) — reached from the Timeline app bar. A menu:
/// the Data subpage, the live Theme/Language pickers (applied app-wide via the
/// shared [SettingsScope] controller), and the About subpage. Theme/language
/// changes apply optimistically and persist; no error UI is needed (a failed
/// persist is logged, the choice still holds for the session).
class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key});

  static Route<void> route() =>
      MaterialPageRoute<void>(builder: (_) => const SettingsPage());

  SettingsController get _controller => SettingsScope.controller;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(l10n.settingsTitle)),
      body: ValueListenableBuilder<SettingsState>(
        valueListenable: _controller.stateHolder,
        builder: (context, state, _) {
          final prefs = state.preferences;
          return ListView(
            children: [
              ListTile(
                leading: const Icon(Icons.folder_outlined),
                title: Text(l10n.settingsDataTitle),
                subtitle: Text(l10n.settingsDataSubtitle),
                trailing: const Icon(Icons.chevron_right),
                onTap: () =>
                    Navigator.of(context).push(SettingsDataPage.route()),
              ),
              const Divider(height: 1),
              ListTile(
                leading: const Icon(Icons.brightness_6_outlined),
                title: Text(l10n.settingsThemeTitle),
                subtitle: Text(_themeLabel(l10n, prefs.themeMode)),
                onTap: () => _pickTheme(context, prefs.themeMode),
              ),
              ListTile(
                leading: const Icon(Icons.language_outlined),
                title: Text(l10n.settingsLanguageTitle),
                subtitle: Text(_languageLabel(l10n, prefs.language)),
                onTap: () => _pickLanguage(context, prefs.language),
              ),
              SwitchListTile(
                secondary: const Icon(Icons.photo_camera_outlined),
                title: Text(l10n.settingsKeepPhotoMetadataTitle),
                subtitle: Text(l10n.settingsKeepPhotoMetadataSubtitle),
                value: prefs.keepPhotoMetadata,
                onChanged: (keep) =>
                    _controller.dispatch(KeepPhotoMetadataToggled(keep)),
              ),
              const Divider(height: 1),
              ListTile(
                leading: const Icon(Icons.info_outline),
                title: Text(l10n.settingsAboutTitle),
                subtitle: Text(l10n.settingsAboutSubtitle),
                trailing: const Icon(Icons.chevron_right),
                onTap: () =>
                    Navigator.of(context).push(SettingsAboutPage.route()),
              ),
            ],
          );
        },
      ),
    );
  }

  Future<void> _pickTheme(BuildContext context, AppThemeMode current) async {
    final l10n = AppLocalizations.of(context);
    final picked = await showModalBottomSheet<AppThemeMode>(
      context: context,
      builder: (_) => _OptionSheet<AppThemeMode>(
        title: l10n.settingsThemeTitle,
        current: current,
        options: [
          for (final mode in AppThemeMode.values)
            (value: mode, label: _themeLabel(l10n, mode)),
        ],
      ),
    );
    if (picked != null) _controller.dispatch(ThemeModeSelected(picked));
  }

  Future<void> _pickLanguage(BuildContext context, AppLanguage current) async {
    final l10n = AppLocalizations.of(context);
    final picked = await showModalBottomSheet<AppLanguage>(
      context: context,
      builder: (_) => _OptionSheet<AppLanguage>(
        title: l10n.settingsLanguageTitle,
        current: current,
        options: [
          for (final lang in AppLanguage.values)
            (value: lang, label: _languageLabel(l10n, lang)),
        ],
      ),
    );
    if (picked != null) _controller.dispatch(LanguageSelected(picked));
  }

  String _themeLabel(AppLocalizations l10n, AppThemeMode mode) =>
      switch (mode) {
        AppThemeMode.system => l10n.settingsThemeSystem,
        AppThemeMode.light => l10n.settingsThemeLight,
        AppThemeMode.dark => l10n.settingsThemeDark,
      };

  String _languageLabel(AppLocalizations l10n, AppLanguage language) =>
      switch (language) {
        AppLanguage.system => l10n.settingsLanguageSystem,
        AppLanguage.english => l10n.settingsLanguageEnglish,
        AppLanguage.russian => l10n.settingsLanguageRussian,
      };
}

/// A single-choice bottom sheet: radio-style rows, the current value checked.
/// Pops the picked value (or null on dismiss). Widget-owned view model of
/// primitives (widgets.md §1) — takes only `(value, label)` rows.
class _OptionSheet<T> extends StatelessWidget {
  const _OptionSheet({
    required this.title,
    required this.current,
    required this.options,
  });

  final String title;
  final T current;
  final List<({T value, String label})> options;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Align(
              alignment: AlignmentDirectional.centerStart,
              child: Text(title, style: theme.textTheme.titleMedium),
            ),
          ),
          for (final option in options)
            ListTile(
              title: Text(option.label),
              trailing: option.value == current
                  ? Icon(Icons.check, color: theme.colorScheme.primary)
                  : null,
              onTap: () => Navigator.of(context).pop(option.value),
            ),
        ],
      ),
    );
  }
}
