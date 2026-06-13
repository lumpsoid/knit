import 'package:fcis_core/fcis_core.dart';
import 'package:knit/features/settings/presentation/settings_action.dart';
import 'package:knit/features/settings/presentation/settings_effect.dart';
import 'package:knit/features/settings/presentation/settings_state.dart';

/// The Settings FCIS loop (fcis.md §6.8) — super-params only, no logic.
class SettingsLoop
    extends FcisLoop<SettingsState, SettingsAction, SettingsEffect> {
  SettingsLoop({
    required super.stateHolder,
    required super.updater,
    required super.effectRunner,
  });
}
