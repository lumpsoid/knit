import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:knit/features/settings/domain/app_version.dart';
import 'package:knit/l10n/app_localizations.dart';

/// The About subpage (§4 settings): app name, tagline, and the version/build.
///
/// The version is read straight from the platform via `package_info_plus` in a
/// FutureBuilder — read-only trivia with no business decision, so it stays a
/// view concern rather than a feature loop (mirrors the inline reads elsewhere).
class SettingsAboutPage extends StatelessWidget {
  const SettingsAboutPage({super.key});

  static Route<void> route() =>
      MaterialPageRoute<void>(builder: (_) => const SettingsAboutPage());

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(l10n.settingsAboutTitle)),
      body: ListView(
        padding: const EdgeInsets.symmetric(vertical: 32, horizontal: 24),
        children: [
          Center(
            child: Column(
              children: [
                Icon(
                  Icons.workspaces_outline,
                  size: 64,
                  color: theme.colorScheme.primary,
                ),
                const SizedBox(height: 16),
                Text(
                  l10n.appTitle,
                  style: theme.textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  l10n.settingsAboutTagline,
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 32),
          FutureBuilder<PackageInfo>(
            future: PackageInfo.fromPlatform(),
            builder: (context, snapshot) {
              final info = snapshot.data;
              final version = info == null
                  ? '—'
                  : AppVersion(
                      info.version,
                      commit: AppVersion.buildCommit,
                    ).label;
              return ListTile(
                leading: const Icon(Icons.tag_outlined),
                title: Text(l10n.settingsAboutVersionLabel),
                subtitle: Text(version),
              );
            },
          ),
        ],
      ),
    );
  }
}
