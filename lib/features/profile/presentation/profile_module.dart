import 'package:effect_emitter/effect_emitter.dart';
import 'package:fcis_core/fcis_core.dart';
import 'package:logging/logging.dart';
import 'package:knit/core/fcis_flutter/fcis_flutter.dart';
import 'package:knit/features/profile/domain/profile_read_repository.dart';
import 'package:knit/features/profile/domain/profile_write_repository.dart';
import 'package:knit/features/profile/presentation/profile_action.dart';
import 'package:knit/features/profile/presentation/profile_controller.dart';
import 'package:knit/features/profile/presentation/profile_effect.dart';
import 'package:knit/features/profile/presentation/profile_loop.dart';
import 'package:knit/features/profile/presentation/profile_shell.dart';
import 'package:knit/features/profile/presentation/profile_state.dart';
import 'package:knit/features/profile/presentation/profile_ui_effect.dart';
import 'package:knit/features/profile/presentation/profile_updater.dart';

/// Composition root for the Profile screen (fcis.md §6.8).
class ProfileModule {
  ProfileModule({
    required ProfileReadRepository readRepository,
    required ProfileWriteRepository writeRepository,
    Logger? logger,
  }) {
    final stateHolder =
        ValueListenableStateHolder<ProfileState>(const ProfileState());
    final effectEmitter = EffectEmitter<ProfileUiEffect>();
    final shell = ProfileShell(
      readRepository: readRepository,
      writeRepository: writeRepository,
      effectEmitter: effectEmitter,
      logger: logger ?? Logger('knit.profile'),
    );
    final loop = ProfileLoop(
      stateHolder: stateHolder,
      updater: const ProfileUpdater(),
      effectRunner:
          ShellEffectRunner<ProfileEffect, ProfileAction>(shell: shell),
    );
    _controller = ProfileController(
      stateHolder: stateHolder,
      effectEmitter: effectEmitter,
      sink: loop,
    );
  }

  late final ProfileController _controller;

  ProfileController get controller => _controller;
}
