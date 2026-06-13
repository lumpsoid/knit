import 'package:fcis_core/fcis_core.dart';
import 'package:knit/features/profile/presentation/profile_action.dart';
import 'package:knit/features/profile/presentation/profile_effect.dart';
import 'package:knit/features/profile/presentation/profile_state.dart';

/// The Profile FCIS loop (fcis.md §6.8) — super-params only, no logic.
class ProfileLoop extends FcisLoop<ProfileState, ProfileAction, ProfileEffect> {
  ProfileLoop({
    required super.stateHolder,
    required super.updater,
    required super.effectRunner,
  });
}
