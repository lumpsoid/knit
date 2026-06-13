import 'package:effect_emitter/effect_emitter.dart';
import 'package:fcis_core/fcis_core.dart';
import 'package:logging/logging.dart';
import 'package:knit/features/settings/domain/settings_read_repository.dart';
import 'package:knit/features/settings/domain/settings_write_repository.dart';
import 'package:knit/features/settings/presentation/settings_action.dart';
import 'package:knit/features/settings/presentation/settings_effect.dart';
import 'package:knit/features/settings/presentation/settings_ui_effect.dart';

/// Imperative shell for Settings (fcis.md §6.6). Unwraps the read/write Results
/// at the seam (result.md §9.3) into success/failure Actions; pushes the
/// "coming soon" UiEffect for the not-yet-built data actions. The updater never
/// sees a Result.
///
/// [RunDataActionEffect] is the seam where export / import / identity backup /
/// wipe / reset will be implemented: replace the placeholder push with the real
/// work (and dispatch result Actions) when each flow lands.
class SettingsShell extends Shell<SettingsEffect, SettingsAction> {
  SettingsShell({
    required SettingsReadRepository readRepository,
    required SettingsWriteRepository writeRepository,
    required EffectEmitter<SettingsUiEffect> effectEmitter,
    required Logger logger,
  })  : _read = readRepository,
        _write = writeRepository,
        _effectEmitter = effectEmitter,
        _log = logger;

  final SettingsReadRepository _read;
  final SettingsWriteRepository _write;
  final EffectEmitter<SettingsUiEffect> _effectEmitter;
  final Logger _log;

  @override
  Future<void> run(
    SettingsEffect effect, {
    required void Function(SettingsAction) dispatch,
  }) async {
    switch (effect) {
      case LoadPreferencesEffect():
        final result = await _read.load();
        result.onTap(
          (preferences) => dispatch(PreferencesLoaded(preferences)),
          (failure) {
            _log.severe('Preferences load failed', failure.error,
                failure.stackTrace);
            dispatch(const PreferencesLoadFailed());
          },
        );
      case SavePreferencesEffect(:final preferences):
        final result = await _write.save(preferences);
        result.onTap(
          (saved) => dispatch(PreferencesSaved(saved)),
          (failure) {
            // The optimistic state already reflects the choice; only the
            // persisted copy was lost, so we log rather than alarm the user.
            _log.severe('Preferences save failed', failure.error,
                failure.stackTrace);
            dispatch(const PreferencesSaveFailed());
          },
        );
      case RunDataActionEffect(:final action):
        _effectEmitter.push(SettingsComingSoonUiEffect(action));
    }
  }
}
