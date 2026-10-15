import 'package:effect_emitter/effect_emitter.dart';
import 'package:fcis_core/fcis_core.dart';
import 'package:flutter/foundation.dart';
import 'package:knit/features/settings/presentation/settings_action.dart';
import 'package:knit/features/settings/presentation/settings_state.dart';
import 'package:knit/features/settings/presentation/settings_ui_effect.dart';

/// Thin controller (fcis.md §6.8). App-wide and shared: the root [KnitApp]
/// observes [stateHolder] for theme/locale, the settings pages dispatch intents,
/// and the Data page attaches the [EffectEmitter] for its "coming soon" notices.
class SettingsController {
  SettingsController({
    required this.stateHolder,
    required EffectEmitter<SettingsUiEffect> effectEmitter,
    required ActionSink<SettingsAction> sink,
  }) : _effectEmitter = effectEmitter,
       _sink = sink;

  final ValueListenable<SettingsState> stateHolder;
  final EffectEmitter<SettingsUiEffect> _effectEmitter;
  final ActionSink<SettingsAction> _sink;

  void onAttach(EffectPusher<SettingsUiEffect> pusher) =>
      _effectEmitter.attach(pusher);

  void onDetach() => _effectEmitter.detach();

  void dispatch(SettingsAction action) => _sink.dispatch(action);
}
