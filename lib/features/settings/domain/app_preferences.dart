import 'package:flutter/foundation.dart';

/// How the app picks its light/dark theme (§4 settings). Domain-neutral — the
/// app layer maps this to Flutter's `ThemeMode` at the edge, so the domain stays
/// free of `package:flutter/material`.
enum AppThemeMode {
  system,
  light,
  dark;

  /// Tolerant tag→enum resolver (dart-helper-fn-placement): unknown / missing
  /// persisted values fall back to [system].
  static AppThemeMode fromName(String? name) => AppThemeMode.values.firstWhere(
    (m) => m.name == name,
    orElse: () => AppThemeMode.system,
  );
}

/// The app's UI language. [system] defers to the device locale; the others pin
/// it. The app layer maps this to a `Locale?` (null = follow the system).
enum AppLanguage {
  system,
  english,
  russian;

  static AppLanguage fromName(String? name) => AppLanguage.values.firstWhere(
    (l) => l.name == name,
    orElse: () => AppLanguage.system,
  );
}

/// This device's UI preferences (theme + language). Device-local config, not
/// synced graph data — persisted in shared_preferences, never the change log.
@immutable
class AppPreferences {
  const AppPreferences({
    this.themeMode = AppThemeMode.system,
    this.language = AppLanguage.system,
  });

  final AppThemeMode themeMode;
  final AppLanguage language;

  AppPreferences copyWith({AppThemeMode? themeMode, AppLanguage? language}) =>
      AppPreferences(
        themeMode: themeMode ?? this.themeMode,
        language: language ?? this.language,
      );

  @override
  bool operator ==(Object other) =>
      other is AppPreferences &&
      other.themeMode == themeMode &&
      other.language == language;

  @override
  int get hashCode => Object.hash(themeMode, language);
}
